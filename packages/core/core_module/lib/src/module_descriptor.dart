import 'package:meta/meta.dart';

/// 模块身份。
///
/// [id] 在同一个 [ModuleRegistry] 内必须唯一（重复注册会在启动阶段直接
/// 抛错，而不是静默覆盖）；[requires] 声明的是**协议级依赖**——「我需要
/// 某个模块已注册」，而不是包依赖。
@immutable
class ModuleDescriptor {
  /// 创建模块描述。
  const ModuleDescriptor({
    required this.id,
    required this.version,
    this.displayName,
    this.requires = const <String>[],
  });

  /// 模块唯一标识（小写，如 `auth`、`product`）。
  final String id;

  /// 模块版本，用于诊断与灰度判断。
  final String version;

  /// 面向人的模块名。
  final String? displayName;

  /// 依赖的其它模块 id。
  final List<String> requires;

  @override
  bool operator ==(Object other) =>
      other is ModuleDescriptor &&
      other.id == id &&
      other.version == version &&
      _sameEntries(other.requires, requires);

  @override
  int get hashCode => Object.hash(id, version, Object.hashAll(requires));

  @override
  String toString() =>
      'ModuleDescriptor($id@$version'
      '${requires.isEmpty ? '' : ', requires: $requires'})';

  static bool _sameEntries(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
