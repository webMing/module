import 'app_logger.dart';
import 'log_record.dart';

/// 把日志记进内存列表的 logger，供测试断言使用。
///
/// 放在 lib 而非 test/helpers，是为了让**每一个**依赖日志的包
/// （core_observability、core_network、feature 模块…）都能直接复用，
/// 不必各自复制一份假 logger。
///
/// 子 logger 与父 logger **共享**记录缓冲：真实日志层级就是这个语义
/// （同一出口），测试里因此可以在父 logger 上断言到所有子来源的日志。
final class MemoryLogger extends BaseLogger {
  /// 创建内存 logger。
  MemoryLogger({super.name = 'memory', super.minLevel = LogLevel.debug})
    : _records = <LogRecord>[];

  MemoryLogger._shared(
    this._records, {
    required super.name,
    required super.minLevel,
  });

  final List<LogRecord> _records;

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
      MemoryLogger._shared(_records, name: name, minLevel: minLevel);

  @override
  void emit(LogRecord record) => _records.add(record);
}
