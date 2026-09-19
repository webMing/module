import 'package:core_error/core_error.dart';
import 'package:core_logger/core_logger.dart';
import 'package:core_observability/core_observability.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录调用次数的性能出口，用于验证门面确实做了转发。
final class _SpyPerformanceMonitor implements PerformanceMonitor {
  final List<String> started = <String>[];

  @override
  PerformanceTrace startTrace(String name) {
    started.add(name);
    return const NoopPerformanceMonitor().startTrace(name);
  }

  @override
  T trace<T>(String name, T Function() body) {
    started.add(name);
    return body();
  }

  @override
  Future<T> traceAsync<T>(String name, Future<T> Function() body) {
    started.add(name);
    return body();
  }
}

/// 记录调用次数的链路出口。
final class _SpyTracer implements Tracer {
  final List<String> spans = <String>[];

  @override
  Span startSpan(String name, {Map<String, Object?>? attributes}) {
    spans.add(name);
    return const NoopTracer().startSpan(name, attributes: attributes);
  }

  @override
  Future<T> trace<T>(
    String name,
    Future<T> Function(Span span) body, {
    Map<String, Object?>? attributes,
  }) {
    spans.add(name);
    return const NoopTracer().trace(name, body, attributes: attributes);
  }
}

void main() {
  group('构造与派生', () {
    test('noop 门面使用空 logger 与空出口', () async {
      final observability = Observability.noop();
      expect(observability.logger, isA<NoopLogger>());
      expect(observability.crash, isA<NoopCrashReporter>());
      expect(observability.analytics, isA<NoopAnalyticsSink>());

      // 不应抛异常。
      await observability.setUserId('demo');
    });

    test('console 门面按开关决定是否输出日志', () {
      expect(
        Observability.console(enableLogging: false).logger,
        isA<NoopLogger>(),
      );
      expect(
        Observability.console(enableLogging: true).logger,
        isA<ConsoleLogger>(),
      );
    });

    test('named 只给 logger 改名，出口保持同一实例', () {
      final crash = InMemoryCrashReporter();
      final base = Observability(logger: MemoryLogger(), crash: crash);
      final child = base.named('auth');

      expect(child.logger.name, 'auth');
      expect(child.crash, same(crash));
      expect(child.analytics, same(base.analytics));
    });
  });

  group('recordFailure', () {
    test('一次调用同时写日志、上报崩溃、打埋点', () async {
      final logger = MemoryLogger();
      final crash = InMemoryCrashReporter();
      final analytics = InMemoryAnalyticsSink();
      final observability = Observability(
        logger: logger,
        crash: crash,
        analytics: analytics,
      );

      const failure = NetworkException(
        '请求失败',
        kind: NetworkErrorKind.timeout,
        code: 'network.timeout',
        cause: 'socket closed',
      );
      await observability.recordFailure(
        failure,
        operation: 'product.load',
        context: const <String, Object?>{'productId': '10001'},
      );

      final record = logger.records.single;
      expect(record.level, LogLevel.error);
      expect(record.message, '请求失败');
      expect(record.error, 'socket closed', reason: '应记录底层 cause');
      expect(record.context, <String, Object?>{
        'operation': 'product.load',
        'code': 'network.timeout',
        'productId': '10001',
      });

      final crashRecord = crash.records.single;
      expect(crashRecord.error, same(failure));
      expect(crashRecord.reason, 'product.load');
      expect(crashRecord.fatal, isFalse);

      expect(analytics.hasEvent('app_error'), isTrue);
      expect(
        analytics.events.single.properties,
        containsPair('productId', '10001'),
      );
    });

    test('无 cause 时记录异常自身，fatal 透传', () async {
      final logger = MemoryLogger();
      final crash = InMemoryCrashReporter();
      final observability = Observability(logger: logger, crash: crash);

      const failure = ConfigException('缺配置', key: 'API_BASE_URL');
      await observability.recordFailure(failure, fatal: true);

      expect(logger.records.single.error, same(failure));
      expect(crash.records.single.fatal, isTrue);
    });

    test('省略 operation 与 code 时不写入多余字段', () async {
      final logger = MemoryLogger();
      final observability = Observability(logger: logger);

      await observability.recordFailure(const UnknownException('坏了'));
      expect(logger.records.single.context, isEmpty);
    });
  });

  group('setUserId', () {
    test('同时透传到崩溃与埋点出口', () async {
      final crash = InMemoryCrashReporter();
      final analytics = InMemoryAnalyticsSink();
      final observability = Observability(
        logger: MemoryLogger(),
        crash: crash,
        analytics: analytics,
      );

      await observability.setUserId('demo');
      expect(crash.userId, 'demo');
      expect(analytics.userId, 'demo');

      await observability.setUserId(null);
      expect(crash.userId, isNull);
      expect(analytics.userId, isNull);
    });
  });

  group('性能与链路出口转发', () {
    test('performance 与 tracing 被真正调用', () async {
      final performance = _SpyPerformanceMonitor();
      final tracing = _SpyTracer();
      final observability = Observability(
        logger: MemoryLogger(),
        performance: performance,
        tracing: tracing,
      );

      expect(observability.performance.trace('sync', () => 1), 1);
      expect(await observability.performance.traceAsync('async', () async {}), isNull);
      observability.performance.startTrace('manual').stop();
      expect(performance.started, <String>['sync', 'async', 'manual']);

      expect(
        await observability.tracing.trace('span', (span) async => 'ok'),
        'ok',
      );
      observability.tracing.startSpan('manual').end();
      expect(tracing.spans, <String>['span', 'manual']);
    });
  });

  group('noop 性能与链路实现', () {
    test('NoopPerformanceMonitor 透传返回值与异常', () async {
      const monitor = NoopPerformanceMonitor();
      expect(monitor.trace('t', () => 'v'), 'v');
      expect(await monitor.traceAsync('t', () async => 'v'), 'v');
      expect(() => monitor.trace('t', () => throw StateError('boom')),
          throwsStateError);

      final trace = monitor.startTrace('t')
        ..putAttribute('k', 'v')
        ..stop();
      expect(trace, isA<PerformanceTrace>());
    });

    test('NoopTracer 记录属性、透传结果并上报异常', () async {
      const tracer = NoopTracer();
      Span? captured;
      final result = await tracer.trace('span', (span) async {
        captured = span..setAttribute('a', 1);
        return 42;
      });
      expect(result, 42);
      expect(captured!.name, 'span');
      expect(captured!.attributes, <String, Object?>{'a': 1});

      await expectLater(
        tracer.trace<void>('bad', (span) async {
          throw StateError('boom');
        }),
        throwsStateError,
      );
    });

    test('startSpan 复制传入属性，不共享外部 Map', () {
      const tracer = NoopTracer();
      final source = <String, Object?>{'a': 1};
      final span = tracer.startSpan('s', attributes: source);
      source['b'] = 2;
      expect(span.attributes, <String, Object?>{'a': 1});
    });
  });
}
