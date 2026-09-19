import 'dart:developer' as developer;

import 'app_logger.dart';
import 'log_record.dart';

/// 输出到 `dart:developer` 的 logger（IDE / DevTools 可按来源过滤）。
final class ConsoleLogger extends BaseLogger {
  /// 创建控制台 logger。
  const ConsoleLogger({super.name = 'app', super.minLevel = LogLevel.debug});

  @override
  ConsoleLogger child(String name) =>
      ConsoleLogger(name: name, minLevel: minLevel);

  @override
  void emit(LogRecord record) {
    developer.log(
      _format(record),
      name: record.name,
      level: _severityOf(record.level),
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }

  static String _format(LogRecord record) {
    final extra = record.context;
    if (extra == null || extra.isEmpty) {
      return record.message;
    }
    return '${record.message} $extra';
  }

  /// 映射到 `dart:developer` 的 severity（0–2000）。
  static int _severityOf(LogLevel level) => switch (level) {
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warn => 900,
    LogLevel.error => 1000,
    LogLevel.off => 2000,
  };
}
