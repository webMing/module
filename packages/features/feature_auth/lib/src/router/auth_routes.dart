import 'package:core_module/core_module.dart';
import 'package:core_router/core_router.dart';
import 'package:core_session/core_session.dart';

import '../domain/repositories/auth_repository.dart';
import '../module/auth_events.dart';
import '../presentation/pages/login_page.dart';
import '../presentation/pages/reset_password_page.dart';

/// 演示环境提示（演示账号与默认密码），由登录 / 重置密码页展示。
const String kAuthDemoHintText = '演示环境：演示账号 demo，默认密码 abc123';

/// 把认证模块的页面路由登记到 [registrar]。
///
/// 路由工厂与回调都在**页面真正被打开时**才执行，因此这里可以安全地通过
/// [ModuleRegistrar.locator] 取用依赖（boot 之前访问会抛错）。
void registerAuthRoutes(ModuleRegistrar registrar) {
  registrar.registerRoute(
    '/login',
    (_) => LoginPage(
      repository: registrar.locator.get<AuthRepository>(),
      demoHintText: kAuthDemoHintText,
      onLoginSuccess: (session) {
        // 会话状态属于 core_session：先落库，再广播「我发生了事情」。
        // 具体跳哪一页由订阅了 LoginSucceededEvent 的一方决定。
        registrar.locator.get<SessionStore>().set(session);
        registrar.locator.get<EventBus>().publish(LoginSucceededEvent(session));
      },
      onForgotPassword: () =>
          registrar.locator.get<AppNavigator>().push('/reset-password'),
    ),
  );

  registrar.registerRoute(
    '/reset-password',
    (_) => ResetPasswordPage(
      repository: registrar.locator.get<AuthRepository>(),
      demoHintText: kAuthDemoHintText,
      onResetSuccess: () {
        final navigator = registrar.locator.get<AppNavigator>();
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          navigator.go('/login');
        }
      },
    ),
  );
}
