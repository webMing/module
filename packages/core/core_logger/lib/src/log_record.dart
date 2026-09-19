import 'package:meta/meta.dart';

/// 日志级别，按严重程度递增。
enum LogLevel {
  /// 开发期细节。
  debug,

  /// 正常流程节点。
  info,

  /// 可恢复的异常情况。
  warn,

  /// 需要关注的失败。
  error,

  /// 关闭日志（用作 [AppLogger.minLevel] 的「全部丢弃」哨兵值）。
  off,
}

/// 一条结构化日志。
@immutable
class LogRecord {
  /// 创建一条日志记录。
  const LogRecord({
    required this.level,
    required this.message,
    required this.name,
    required this.timestamp,
    this.error,
    this.stackTrace,
    this.context,
  });

  /// 级别。
  final LogLevel level;

  /// 描述文本。
  final String message;

  /// 来源名称（通常是子 logger 名，如 `auth.login`）。
  final String name;

  /// 产生时间。
  final DateTime timestamp;

  /// 伴随的异常对象。
  final Object? error;

  /// 伴随的堆栈。
  final StackTrace? stackTrace;

  /// 结构化附加字段，用于埋点 / 检索。
  final Map<String, Object?>? context;

  @override
  String toString() {
    final buffer = StringBuffer('${level.name.toUpperCase()} $name: $message');
    final extra = context;
    if (extra != null && extra.isNotEmpty) {
      buffer.write(' $extra');
    }
    return buffer.toString();
  }
}
