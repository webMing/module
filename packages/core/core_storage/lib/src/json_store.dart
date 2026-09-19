import 'dart:convert';

import 'package:core_error/core_error.dart';
import 'package:core_model/core_model.dart';

import 'key_value_store.dart';

/// 在 [KeyValueStore] 之上读写 JSON 结构。
///
/// [namespace] 用于隔离不同模块的键空间，避免两个 feature 恰好用了相同的
/// 短键名而互相覆盖（前缀形如 `auth.session`）。
class JsonStore {
  /// 创建一个 JSON 读写器。
  const JsonStore(this._store, {this.namespace});

  final KeyValueStore _store;

  /// 键空间前缀，为空时直接使用原键。
  final String? namespace;

  String _scoped(String key) {
    ensureValidKey(key);
    final prefix = namespace;
    return prefix == null ? key : '$prefix.$key';
  }

  /// 读取一个对象，不存在返回 null；内容非法时抛 [StorageException]。
  Future<JsonMap?> readMap(String key) async {
    final raw = await _store.read(_scoped(key));
    if (raw == null) {
      return null;
    }
    return decodeMap(raw, key: key);
  }

  /// 写入一个对象。
  Future<void> writeMap(String key, JsonMap value) =>
      _store.write(_scoped(key), jsonEncode(value));

  /// 删除一个键。
  Future<void> delete(String key) => _store.delete(_scoped(key));

  /// 键是否存在。
  Future<bool> containsKey(String key) => _store.containsKey(_scoped(key));

  /// 把原始 JSON 文本解析成 [JsonMap]。
  ///
  /// 损坏的数据（手工改坏、旧版本格式）不应让应用崩溃，因此统一包装成
  /// [StorageException]，由调用方决定丢弃还是上报。
  static JsonMap decodeMap(String raw, {String? key}) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('JSON 根节点不是对象');
      }
      return decoded.cast<String, Object?>();
    } on Object catch (error, stackTrace) {
      throw StorageException(
        'JSON 解析失败',
        key: key,
        code: 'storage.invalid_json',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
