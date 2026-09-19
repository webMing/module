import 'package:meta/meta.dart';

/// 领域实体基类：以 [id] 判定相等性。
///
/// 相等性同时要求 [runtimeType] 相同，避免两个不同实体恰好 id 相同时
/// 被判为相等（例如 `User(id: 1)` 与 `Order(id: 1)`）。
@immutable
abstract class Entity<T extends Object> {
  /// 以唯一标识创建实体。
  const Entity(this.id);

  /// 实体唯一标识。
  final T id;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Entity<T> &&
        other.runtimeType == runtimeType &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(runtimeType, id);

  @override
  String toString() => '$runtimeType($id)';
}
