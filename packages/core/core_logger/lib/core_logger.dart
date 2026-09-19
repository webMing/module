/// 日志抽象：级别、结构化记录与控制台实现。
///
/// 业务代码只依赖 [AppLogger] 接口，不直接使用 `print` / `developer.log` /
/// 任何第三方日志库，保证日志出口可被 [Observability] 统一接管。
library;

export 'src/app_logger.dart';
export 'src/console_logger.dart';
export 'src/log_record.dart';
export 'src/memory_logger.dart';
export 'src/noop_logger.dart';
