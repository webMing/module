/// 路由能力：模块路由定义、go_router 装配与导航端口。
///
/// 分工（对应架构文档第 9 章）：
/// * **收集**路由属于模块系统——模块通过 [ModuleRegistrarRoutes] 登记
///   [RouteDefinition]；
/// * **解析与跳转**属于 go_router——由 [AppRouter] 装配并执行。
///
/// `core_router` → `core_module`（靠 [ModuleContribution] 接入），
/// 反向不依赖，因此模块系统本身保持纯 Dart。
library;

export 'src/app_router.dart';
export 'src/module_registrar_routes.dart';
export 'src/module_route.dart';
