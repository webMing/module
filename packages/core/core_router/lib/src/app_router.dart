import 'dart:async';

import 'package:core_module/core_module.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'module_route.dart';

/// 应用导航端口。
///
/// 模块与协议依赖它而不是 go_router，替换路由实现时改动被限制在本包。
abstract interface class AppNavigator {
  /// 跳转并替换当前栈顶。
  Future<void> go(String location);

  /// 压入新页面。
  Future<void> push(String location);

  /// 返回上一页（无可返回时不动作）。
  void pop();

  /// 是否有可返回的页面。
  bool canPop();
}

/// 由模块贡献组装出来的应用路由。
///
/// 同时实现 [AppNavigator]（给页面用）与 [ModuleNavigator]（给 ModuleBus
/// 用），于是「协议 → 跳转」这条链路不需要额外的胶水代码。
class AppRouter implements AppNavigator, ModuleNavigator {
  /// 用已有 [GoRouter] 创建（测试常用）。
  AppRouter({required this.router});

  /// 由路由定义装配 go_router。
  ///
  /// [initialLocation] 是应用起始位置（通常是登录页）；`/` 被保留为
  /// 指向它的重定向，因此模块不应注册 `/`。
  factory AppRouter.fromRoutes({
    required Iterable<RouteDefinition> routes,
    required String initialLocation,
    Widget Function(BuildContext context, GoRouterState state)? errorBuilder,
    bool debugLogDiagnostics = false,
  }) {
    final definitions = routes.toList(growable: false);
    _validate(definitions);

    return AppRouter(
      router: GoRouter(
        initialLocation: initialLocation,
        debugLogDiagnostics: debugLogDiagnostics,
        errorBuilder: errorBuilder,
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            redirect: (BuildContext context, GoRouterState state) =>
                initialLocation,
          ),
          for (final definition in definitions)
            GoRoute(
              path: definition.path,
              name: definition.name,
              builder: (BuildContext context, GoRouterState state) =>
                  definition.factory(ModuleRouteContext.fromState(state)),
            ),
        ],
      ),
    );
  }

  /// 直接取注册表里所有模块贡献的路由。
  factory AppRouter.fromRegistry(
    ModuleRegistry registry, {
    required String initialLocation,
    Widget Function(BuildContext context, GoRouterState state)? errorBuilder,
    bool debugLogDiagnostics = false,
  }) => AppRouter.fromRoutes(
    routes: registry.contributionsOf<RouteDefinition>(),
    initialLocation: initialLocation,
    errorBuilder: errorBuilder,
    debugLogDiagnostics: debugLogDiagnostics,
  );

  /// 底层路由器（交给 `MaterialApp.router` / `CupertinoApp.router`）。
  final GoRouter router;

  @override
  Future<void> go(String location) async => router.go(location);

  @override
  Future<void> push(String location) {
    // 刻意不 await：go_router 的 push Future 要等到被压入的页面 **pop**
    // 时才完成，await 它会让调用方一直挂到用户返回为止。
    unawaited(router.push<void>(location));
    return Future<void>.value();
  }

  @override
  void pop() {
    if (router.canPop()) {
      router.pop();
    }
  }

  @override
  bool canPop() => router.canPop();

  /// [ModuleNavigator] 的实现：把协议意图落到 go_router。
  @override
  Future<void> open(String location) => go(location);

  /// 释放路由器资源。
  void dispose() => router.dispose();

  static void _validate(List<RouteDefinition> definitions) {
    final seen = <String>{};
    for (final definition in definitions) {
      if (definition.path == '/') {
        throw StateError('路由路径 / 由应用保留（重定向到初始位置）');
      }
      if (!seen.add(definition.path)) {
        throw StateError('路由路径重复注册：${definition.path}');
      }
    }
  }
}
