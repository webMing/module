import 'package:core_module/core_module.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// 页面工厂：由路由上下文构造页面。
///
/// 用上下文而不是 `Widget Function()`，是为了让带路径参数的页面也能用同一个
/// API（`/product/detail/:id` → `context.pathParam('id')`）。
typedef ModulePageFactory = Widget Function(ModuleRouteContext context);

/// 路由上下文：把 go_router 的 `GoRouterState` 收敛成本包的类型。
///
/// 这样页面不需要 import go_router，也就不会出现「业务模块直接依赖路由库」
/// 的泄漏。
@immutable
class ModuleRouteContext {
  /// 直接构造。
  const ModuleRouteContext({
    required this.path,
    this.pathParameters = const <String, String>{},
    this.queryParameters = const <String, String>{},
    this.extra,
  });

  /// 从 go_router 状态构造。
  factory ModuleRouteContext.fromState(GoRouterState state) =>
      ModuleRouteContext(
        path: state.uri.path,
        pathParameters: state.pathParameters,
        queryParameters: state.uri.queryParameters,
        extra: state.extra,
      );

  /// 当前路径（不含 query）。
  final String path;

  /// 路径参数（`/product/:id` → `{'id': ...}`）。
  final Map<String, String> pathParameters;

  /// 查询参数。
  final Map<String, String> queryParameters;

  /// 跳转时携带的额外对象。
  final Object? extra;

  /// 读取路径参数。
  String? pathParam(String name) => pathParameters[name];

  /// 读取查询参数。
  String? query(String name) => queryParameters[name];

  @override
  String toString() => 'ModuleRouteContext($path)';
}

/// 一条模块路由。
@immutable
class RouteDefinition implements ModuleContribution {
  /// 用页面工厂创建。
  const RouteDefinition({required this.path, required this.factory, this.name});

  /// 用无参数页面创建（`HomePage.new` 这类构造函数可直接传入）。
  RouteDefinition.page(String path, Widget Function() builder, {String? name})
    : this(path: path, factory: (_) => builder(), name: name);

  /// 路径，可含 `:name` 占位符。
  final String path;

  /// 页面工厂。
  final ModulePageFactory factory;

  /// 命名路由（用于 `pushNamed`）。
  final String? name;

  @override
  String toString() => 'RouteDefinition($path)';
}
