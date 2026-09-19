/// 共享基础模型：实体基类与 JSON 类型约定。
///
/// 这一层只放**跨模块共享**的最小类型。任何带业务含义的模型都应该留在
/// 它所属的 feature 模块内，不要往这里堆。
library;

export 'src/entity.dart';
export 'src/json_map.dart';
