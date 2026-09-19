import 'package:core_module/core_module.dart';
import 'package:flutter/widgets.dart';

import 'module_route.dart';

/// 让模块用 `registrar.registerRoute(...)` / `registerPage(...)` 登记路由。
///
/// 这是 [ModuleContribution] 机制的实际用法：`core_router` 通过扩展挂到
/// `ModuleRegistrar` 上，于是 `core_module` 不需要认识 `Widget`。
extension ModuleRegistrarRoutes on ModuleRegistrar {
  /// 登记一条带参数的页面路由。
  ///
  /// ```dart
  /// registrar.registerRoute(
  ///   '/product/detail/:id',
  ///   (context) => ProductDetailPage(id: context.pathParam('id')!),
  /// );
  /// ```
  void registerRoute(
    String path,
    ModulePageFactory factory, {
    String? name,
  }) => contribute(RouteDefinition(path: path, factory: factory, name: name));

  /// 登记一条无参数页面路由。
  ///
  /// ```dart
  /// registrar.registerPage('/home', HomePage.new);
  /// ```
  void registerPage(
    String path,
    Widget Function() builder, {
    String? name,
  }) => contribute(RouteDefinition.page(path, builder, name: name));
}
