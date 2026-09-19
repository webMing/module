/// 可观测性门面：日志 / 崩溃 / 埋点 / 性能 / Tracing 的统一入口。
///
/// 业务代码只依赖本包：
///
/// ```dart
/// observability.logger.error('商品加载失败', error: error);
/// ```
///
/// **不要**在业务代码里直接调用 `FirebaseCrashlytics.instance...` 之类的
/// 第三方 SDK——更换供应商时应该只改本包（或应用装配层）的实现绑定。
library;

export 'src/analytics_sink.dart';
export 'src/crash_reporter.dart';
export 'src/observability.dart';
export 'src/performance_monitor.dart';
export 'src/tracer.dart';
