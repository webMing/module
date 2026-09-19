/// 解码后的 JSON 对象。
typedef JsonMap = Map<String, Object?>;

/// 解码后的 JSON 数组。
typedef JsonList = List<Object?>;

/// [JsonMap] 的强类型读取扩展。
///
/// 设计取舍：**类型不符一律当作缺失（返回 null）**，而不是抛异常。
/// 接口字段偶尔变化时，缺失字段退化为默认值比整页崩溃更可接受；
/// 真正必填的字段用 `requireXxx` 显式声明意图并抛出 [FormatException]。
extension JsonMapReader on JsonMap {
  /// 读取 [key] 并断言为 [T]；类型不符或缺失时返回 null。
  T? read<T>(String key) {
    final value = this[key];
    return value is T ? value : null;
  }

  /// 读取字符串。
  String? readString(String key) => read<String>(key);

  /// 读取必填字符串，缺失时抛出 [FormatException]。
  String requireString(String key) {
    final value = readString(key);
    if (value == null) {
      throw FormatException('缺少必填字段 "$key"', this);
    }
    return value;
  }

  /// 读取整数。
  int? readInt(String key) => read<int>(key);

  /// 读取浮点数；JSON 里的整数值（如 `1`）也会被接受。
  double? readDouble(String key) {
    final value = this[key];
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return null;
  }

  /// 读取布尔值。
  bool? readBool(String key) => read<bool>(key);

  /// 读取 ISO-8601 时间字符串。
  DateTime? readDateTime(String key) {
    final raw = readString(key);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// 读取嵌套对象。
  JsonMap? readMap(String key) => read<JsonMap>(key);

  /// 读取对象数组，并只保留 [T] 类型的元素。
  List<T>? readList<T>(String key) {
    final raw = this[key];
    if (raw is! List) {
      return null;
    }
    return raw.whereType<T>().toList(growable: false);
  }
}
