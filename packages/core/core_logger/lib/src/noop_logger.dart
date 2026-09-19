import 'app_logger.dart';
import 'log_record.dart';

/// 丢弃一切日志的 logger。
///
/// 用于测试与「明确不希望有日志输出」的场景，避免到处写 `if (enabled)`。
final class NoopLogger implements AppLogger {
  /// 创建一个空 logger。
  const NoopLogger({this.name = 'noop'});

  @override
  final String name;

  @override
  LogLevel get minLevel => LogLevel.off;

  @override
  bool isEnabled(LogLevel level) => false;

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {}

  @override
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {}

  @override
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {}

  @override
  void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {}

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {}

  @override
  AppLogger child(String name) => this;
}
