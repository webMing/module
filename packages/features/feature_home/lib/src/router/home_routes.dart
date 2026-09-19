import 'package:core_module/core_module.dart';
import 'package:core_router/core_router.dart';
import 'package:core_session/core_session.dart';
import 'package:signals/signals_flutter.dart';

import '../module/home_events.dart';
import '../presentation/pages/home_page.dart';

/// 登记首页模块的路由。
///
/// `/home` 是登录后的落地页。页面在**路由工厂**里才读取 `registrar.locator`：
/// `register` 阶段容器尚未就绪（此时访问 [ModuleRegistrar.locator] 会抛
/// StateError），而路由工厂在 boot 之后、真正构建页面时才执行。
///
/// 页面用 [SignalBuilder] 包住并读取会话信号，所以会话变化（登录 / 退出）
/// 会精确重建首页，不需要整棵应用 setState。
void registerHomeRoutes(ModuleRegistrar registrar) {
  registrar.registerRoute(
    '/home',
    (context) => SignalBuilder(
      builder: (context) {
        final session = registrar.locator.get<SessionStore>().session.value;
        return HomePage(
          account: session?.account ?? '',
          loginMethodLabel: session?.method.label,
          onLogout: () => registrar.locator
              .get<EventBus>()
              .publish(const LogoutRequestedEvent()),
        );
      },
    ),
  );
}
