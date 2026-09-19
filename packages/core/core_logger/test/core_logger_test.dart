import 'package:core_logger/core_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('级别过滤', () {
    test('低于 minLevel 的记录被丢弃', () {
      final logger = MemoryLogger(minLevel: LogLevel.warn)
        ..debug('d')
        ..info('i')
        ..warn('w')
        ..error('e');

      expect(logger.records.map((r) => r.message), <String>['w', 'e']);
    });

    test('minLevel 为 off 时全部丢弃', () {
      final logger = MemoryLogger(minLevel: LogLevel.off)..error('e');
      expect(logger.records, isEmpty);
      expect(logger.isEnabled(LogLevel.error), isFalse);
    });

    test('isEnabled 对 off 级别永远为 false', () {
      final logger = MemoryLogger(minLevel: LogLevel.debug);
      expect(logger.isEnabled(LogLevel.off), isFalse);
      expect(logger.isEnabled(LogLevel.error), isTrue);
    });
  });

  group('LogRecord', () {
    test('携带级别、来源、结构化字段与错误', () {
      final logger = MemoryLogger(name: 'auth')
        ..error(
          '登录失败',
          error: StateError('boom'),
          context: const <String, Object?>{'account': 'demo'},
        );

      final record = logger.records.single;
      expect(record.level, LogLevel.error);
      expect(record.name, 'auth');
      expect(record.message, '登录失败');
      expect(record.error, isA<StateError>());
      expect(record.context, <String, Object?>{'account': 'demo'});
      expect(record.timestamp, isNotNull);
    });

    test('toString 含大写级别、来源与上下文字段', () {
      final logger = MemoryLogger(name: 'net')
        ..warn('慢', context: const <String, Object?>{'ms': 900});
      expect(logger.records.single.toString(), 'WARN net: 慢 {ms: 900}');
    });

    test('无上下文时 toString 不追加空对象', () {
      final logger = MemoryLogger()..info('ok');
      expect(logger.records.single.toString(), 'INFO memory: ok');
    });
  });

  group('child', () {
    test('改名但继承 minLevel，且不共享记录', () {
      final parent = MemoryLogger(name: 'app', minLevel: LogLevel.info);
      final child = parent.child('app.db');

      child.info('查询完成');
      expect(child.name, 'app.db');
      expect(child.minLevel, LogLevel.info);
      expect(child.records.single.name, 'app.db');
      expect(parent.records, isEmpty);
      expect(child.isEnabled(LogLevel.debug), isFalse);
    });
  });

  group('MemoryLogger 断言助手', () {
    test('hasLevel 与 hasMessage', () {
      final logger = MemoryLogger()..error('炸了');
      expect(logger.hasLevel(LogLevel.error), isTrue);
      expect(logger.hasLevel(LogLevel.warn), isFalse);
      expect(logger.hasMessage('炸了'), isTrue);
      expect(logger.hasMessage('没事'), isFalse);
    });

    test('records 是只读视图，clear 清空', () {
      final logger = MemoryLogger()..info('a');
      expect(() => logger.records.add(logger.records.first), throwsUnsupportedError);
      logger.clear();
      expect(logger.records, isEmpty);
    });
  });

  group('NoopLogger', () {
    test('丢弃一切，child 返回自身', () {
      const logger = NoopLogger();
      logger.error('e', error: StateError('x'));
      expect(logger.minLevel, LogLevel.off);
      expect(logger.isEnabled(LogLevel.error), isFalse);
      expect(logger.child('x'), same(logger));
    });
  });

  group('ConsoleLogger', () {
    test('可构造并继承配置（不校验输出格式）', () {
      const logger = ConsoleLogger(name: 'console', minLevel: LogLevel.error);
      expect(logger.name, 'console');
      expect(logger.minLevel, LogLevel.error);
      expect(logger.child('sub').minLevel, LogLevel.error);
      expect(logger.child('sub').name, 'sub');
      // 只是确保真实输出路径不抛异常。
      logger.warn('被过滤');
      logger.error('会被输出');
    });
  });
}
