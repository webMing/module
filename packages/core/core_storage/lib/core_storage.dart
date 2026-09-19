/// 持久化抽象：键值存储接口、内存实现与 JSON 读写助手。
///
/// 应用侧只依赖 [KeyValueStore] 抽象；换成 `shared_preferences`、Hive、
/// SQLite 都只需在本包（或应用装配层）新增一个实现。
library;

export 'src/in_memory_key_value_store.dart';
export 'src/json_store.dart';
export 'src/key_value_store.dart';
