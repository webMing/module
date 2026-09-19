import 'package:core_error/core_error.dart';
import 'package:core_logger/core_logger.dart';
import 'package:meta/meta.dart';

import 'analytics_sink.dart';
import 'crash_reporter.dart';
import 'performance_monitor.dart';
import 'tracer.dart';

/// 可观测性门面：把日志 / 崩溃 / 埋点 / 性能 / 链路五个出口收在一起。
///
/// 模块只需依赖本对象，供应商（Crashlytics、Sentry、自建上报…）的绑定
/// 留在应用装配层。
@immutable
class Observability {
  /// 组装一个门面；未提供的出口退化为对应 noop 实现。
  const Observability({
    required this.logger,
    this.crash = const NoopCrashReporter(),
    this.analytics = const NoopAnalyticsSink(),
    this.performance = const NoopPerformanceMonitor(),
    this.tracing = const NoopTracer(),
  });

  /// 什么都不做的门面（测试默认值）。
  factory Observability.noop() => const Observability(logger: NoopLogger());

  /// 只写控制台的门面，按 [enableLogging] 决定是否真正输出。
  factory Observability.console({
    bool enableLogging = true,
    LogLevel minLevel = LogLevel.debug,
  }) => Observability(
    logger: enableLogging
        ? ConsoleLogger(minLevel: minLevel)
        : const NoopLogger(),
  );

  /// 日志出口。
  final AppLogger logger;

  /// 崩溃出口。
  final CrashReporter crash;

  /// 埋点出口。
  final AnalyticsSink analytics;

  /// 性能出口。
  final PerformanceMonitor performance;

  /// 链路出口。
  final Tracer tracing;

  /// 派生出带来源名的门面：只有 logger 改名，其余出口共享。
  Observability named(String name) => Observability(
    logger: logger.child(name),
    crash: crash,
    analytics: analytics,
    performance: performance,
    tracing: tracing,
  );

  /// 关联用户标识（登录成功后传入账号，登出时传 null）。
  Future<void> setUserId(String? userId) async {
    await crash.setUserId(userId);
    await analytics.setUserId(userId);
  }

  /// 统一记录一次失败：日志 + 崩溃上报 + 埋点一次完成。
  ///
  /// 这是业务代码面对 [AppException] 时**唯一**需要调用的方法，
  /// 避免「只打了日志但没上报崩溃」这类遗漏。
  Future<void> recordFailure(
    AppException error, {
    String? operation,
    Map<String, Object?>? context,
    bool fatal = false,
  }) async {
    final fields = <String, Object?>{
      'operation': ?operation,
      'code': ?error.code,
      ...?context,
    };

    logger.error(
      error.message,
      error: error.cause ?? error,
      stackTrace: error.effectiveStackTrace,
      context: fields,
    );

    await crash.recordError(
      error,
      error.effectiveStackTrace,
      reason: operation,
      fatal: fatal,
    );

    await analytics.track(
      'app_error',
      properties: <String, Object?>{
        'message': error.message,
        ...fields,
      },
    );
  }
}
