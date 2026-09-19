import 'package:core_module/core_module.dart';

import '../protocol/home_protocol.dart';
import '../router/home_routes.dart';
import 'home_descriptor.dart';

/// 首页模块：登录后的落地页。
///
/// 只声明「我提供什么」：一条 `/home` 路由与一个 `home` 协议。
/// 它没有自己的依赖——页面要渲染的会话来自 `core_session`，因此
/// [register] 里不登记任何 DI，也不触碰容器。
class HomeModule implements AppModule {
  /// 创建首页模块。
  const HomeModule();

  @override
  ModuleDescriptor get descriptor => homeModuleDescriptor;

  @override
  void register(ModuleRegistrar registrar) {
    registerHomeRoutes(registrar);
    registrar.registerProtocol(const HomeProtocol());
  }
}
