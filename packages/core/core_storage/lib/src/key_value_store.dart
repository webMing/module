import 'package:core_error/core_error.dart';

/// 字符串键值存储抽象。
///
/// 只处理 `String -> String`，复杂结构交给 [JsonStore] 序列化，
/// 这样任何后端实现都只需要关心最小的一组原语。
abstract interface class KeyValueStore {
  /// 读取 [key] 的值，不存在时返回 null。
  Future<String?> read(String key);

  /// 写入 [key]。
  Future<void> write(String key, String value);

  /// 删除 [key]，键不存在时不报错。
  Future<void> delete(String key);

  /// [key] 是否存在。
  Future<bool> containsKey(String key);

  /// 清空全部数据。
  Future<void> clear();

  /// 当前所有键。
  Future<Set<String>> keys();
}

/// 校验存储键合法（非空、非纯空白）。
///
/// 各实现都应在每个操作入口调用它，保证契约一致——
/// 空键往往意味着上游拼错了 key，静默写入会造成难以排查的脏数据。
void ensureValidKey(String key) {
  if (key.trim().isEmpty) {
    throw const StorageException('存储键不能为空', code: 'storage.empty_key');
  }
}
