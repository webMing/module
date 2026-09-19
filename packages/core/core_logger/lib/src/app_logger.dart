import 'package:meta/meta.dart';

import 'log_record.dart';

/// 日志接口。
///
/// 所有模块通过它写日志，从而与具体实现（控制台 / 远程上报）解耦。
abstract interface class AppLogger {
  /// 来源名称。
  String get name;

  /// 低于该级别的记录会被直接丢弃。
  LogLevel get minLevel;

  /// [level] 是否会被真正输出。
  bool isEnabled(LogLevel level);

  /// 写一条指定级别的日志。
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  });

  /// 写一条 debug 日志。
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  });

  /// 写一条 info 日志。
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  });

  /// 写一条 warn 日志。
  void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  });

  /// 写一条 error 日志。
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  });

  /// 派生子 logger，只改 [name]，其余配置继承。
  AppLogger child(String name);
}

/// 实现 [AppLogger] 的通用基类：负责级别过滤与便捷方法，子类只需实现
/// [emit] 决定「日志最终去哪」。
abstract base class BaseLogger implements AppLogger {
  /// 创建一个 logger。
  const BaseLogger({this.name = 'app', this.minLevel = LogLevel.debug});

  @override
  final String name;

  @override
  final LogLevel minLevel;

  /// 真正落地输出。只有通过了 [isEnabled] 的记录才会到达这里。
  @protected
  void emit(LogRecord record);

  @override
  bool isEnabled(LogLevel level) =>
      level != LogLevel.off && level.index >= minLevel.index;

  @override
  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    if (!isEnabled(level)) {
      return;
    }
    emit(
      LogRecord(
        level: level,
        message: message,
        name: name,
        timestamp: DateTime.now(),
        error: error,
        stackTrace: stackTrace,
        context: context,
      ),
    );
  }

  @override
  void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) => log(
    LogLevel.debug,
    message,
    error: error,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) => log(
    LogLevel.info,
    message,
    error: error,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  void warn(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) => log(
    LogLevel.warn,
    message,
    error: error,
    stackTrace: stackTrace,
    context: context,
  );

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) => log(
    LogLevel.error,
    message,
    error: error,
    stackTrace: stackTrace,
    context: context,
  );
}
