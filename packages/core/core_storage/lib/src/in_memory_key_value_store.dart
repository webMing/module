import 'key_value_store.dart';

/// [KeyValueStore] 的内存实现。
///
/// 用途：
/// * 单元测试（无需真实磁盘）；
/// * 桌面 / 测试环境下的降级实现；
/// * 作为「会话缓存」这类可丢失数据的临时层。
final class InMemoryKeyValueStore implements KeyValueStore {
  /// 可选地以一份初始数据创建。
  InMemoryKeyValueStore({Map<String, String>? initial})
    : _data = <String, String>{...?initial};

  final Map<String, String> _data;

  /// 当前数据的只读快照（便于测试断言）。
  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_data);

  @override
  Future<String?> read(String key) async {
    ensureValidKey(key);
    return _data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    ensureValidKey(key);
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    ensureValidKey(key);
    _data.remove(key);
  }

  @override
  Future<bool> containsKey(String key) async {
    ensureValidKey(key);
    return _data.containsKey(key);
  }

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<Set<String>> keys() async => Set<String>.unmodifiable(_data.keys);
}
