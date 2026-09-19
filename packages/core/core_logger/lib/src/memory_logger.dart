import 'app_logger.dart';
import 'log_record.dart';

/// 把日志记进内存列表的 logger，供测试断言使用。
///
/// 放在 lib 而非 test/helpers，是为了让**每一个**依赖日志的包
/// （core_observability、core_network、feature 模块…）都能直接复用，
/// 不必各自复制一份假 logger。
final class MemoryLogger extends BaseLogger {
  /// 创建内存 logger。
  MemoryLogger({super.name = 'memory', super.minLevel = LogLevel.debug});

  final List<LogRecord> _records = <LogRecord>[];

  /// 已记录的日志（只读视图）。
  List<LogRecord> get records => List<LogRecord>.unmodifiable(_records);

  /// 清空记录。
  void clear() => _records.clear();

  /// 是否记录过 [level] 级别的日志。
  bool hasLevel(LogLevel level) =>
      _records.any((record) => record.level == level);

  /// 按 [message] 精确匹配是否出现过。
  bool hasMessage(String message) =>
      _records.any((record) => record.message == message);

  @override
  MemoryLogger child(String name) =>
      MemoryLogger(name: name, minLevel: minLevel);

  @override
  void emit(LogRecord record) => _records.add(record);
}
