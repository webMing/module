import 'package:core_module/core_module.dart';

import '../data/datasources/auth_service.dart';
import '../data/datasources/fake_auth_service.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../protocol/auth_protocol.dart';
import '../router/auth_routes.dart';
import 'auth_descriptor.dart';

/// 认证模块。
///
/// 把「账号密码登录 / 短信验证码登录 / 重置密码」这一组能力注册进模块系统：
/// 路由、对外协议与依赖。模块只描述自己要提供什么，不掌握注册表，也不
/// 直接导航——登录成功只写入会话并广播事件。
class AuthModule implements AppModule {
  /// 创建认证模块。
  const AuthModule();

  @override
  ModuleDescriptor get descriptor => authModuleDescriptor;

  @override
  void register(ModuleRegistrar registrar) {
    registerAuthRoutes(registrar);
    registrar.registerProtocol(const AuthProtocol());

    // 数据源兜底：只有应用没有自己注册 AuthService 时才安装演示实现。
    //
    // 必须放在 onBoot 而不是 register 里——register 阶段容器尚未就绪，
    // 而 boot 动作执行时应用的基础设施已经注册完毕。于是：
    // * 生产环境在 boot 之前注册真实后端实现即可覆盖；
    // * 测试注入零延迟假实现，同样不会被覆盖。
    registrar.onBoot((locator) {
      if (!locator.isRegistered<AuthService>()) {
        locator.registerLazySingleton<AuthService>(() => FakeAuthService());
      }
    });

    registrar.lazySingleton<AuthRepository>(
      (locator) => AuthRepositoryImpl(locator.get<AuthService>()),
    );
  }
}
