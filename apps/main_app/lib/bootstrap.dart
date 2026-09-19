/// 应用装配层（Composition Root）。
///
/// 这里是**唯一**允许同时认识「基础设施」与「业务模块」的地方：
/// * 它决定用哪个数据源、哪个日志出口、哪个崩溃上报；
/// * 它把模块装进 [ModuleRegistry] 并 boot；
/// * 它订阅跨模块事件，决定 UI 如何响应。
///
/// 除此之外没有任何业务逻辑——所有页面与状态都在 feature 模块里。
library;

import 'dart:async';

import 'package:core_config/core_config.dart';
import 'package:core_di/core_di.dart';
import 'package:core_logger/core_logger.dart';
import 'package:core_module/core_module.dart';
import 'package:core_observability/core_observability.dart';
import 'package:core_router/core_router.dart';
import 'package:core_session/core_session.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/testing.dart';
import 'package:feature_home/feature_home.dart';

import 'src/app.dart';

/// 装配结果：应用运行期需要的一切。
class Bootstrap {
  Bootstrap._({
    required this.config,
    required this.locator,
    required this.observability,
    required this.eventBus,
    required this.registry,
    required this.appRouter,
    required this.moduleBus,
    required this.sessionStore,
    required this.subscriptions,
  });

  /// 按固定顺序装配整个应用。
  ///
  /// [deepLink] 是外部唤起地址（推送/深链），会与模块内部协议走**同一条**
  /// 链路：`Deep Link → Module Protocol → Module`。
  ///
  /// [registerInfrastructure] 用于替换基础设施绑定，测试据此注册零延迟的
  /// 假数据源；生产环境留空即可。
  static Future<Bootstrap> run({
    AppConfig? config,
    String? deepLink,
    void Function(ServiceLocator locator)? registerInfrastructure,
  }) async {
    // 1) 配置：宁可启动即失败，也不要在生产环境第一次发请求时才暴露问题。
    final appConfig = config ?? AppConfig.fromEnvironment();
    appConfig.validate();

    // 2) 可观测性先就位，后续每一步都能上报。
    final logger = ConsoleLogger(
      minLevel: appConfig.enableLogging ? LogLevel.debug : LogLevel.off,
    );
    final observability = Observability(logger: logger);

    // 3) 容器与基础设施。
    final locator = ServiceLocator();
    final eventBus = EventBus(
      onError: (error, stackTrace) => observability.logger.error(
        '事件订阅者抛出异常',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    final sessionStore = SessionStore(storage: InMemoryKeyValueStore());

    locator
      ..registerSingleton<AppConfig>(appConfig)
      ..registerSingleton<AppLogger>(logger)
      ..registerSingleton<Observability>(observability)
      ..registerSingleton<EventBus>(eventBus)
      ..registerSingleton<SessionStore>(sessionStore);

    // 4) 数据源：由应用决定接真实后端还是本地假实现。
    (registerInfrastructure ?? registerDemoInfrastructure)(locator);

    // 5) 恢复上次会话（损坏数据会被安全丢弃）。
    await sessionStore.restore();

    // 6) 模块清单 + boot：收集能力、校验依赖与协议冲突、应用模块依赖。
    final registry = ModuleRegistry()
      ..register(const AuthModule())
      ..register(const HomeModule());
    registry.boot(locator);

    // 7) 路由：路由表完全来自模块贡献，应用不写任何 GoRoute。
    final appRouter = AppRouter.fromRegistry(
      registry,
      initialLocation: '/login',
      errorBuilder: (context, state) => RouteErrorPage(message: '${state.error}'),
    );
    locator.registerSingleton<AppNavigator>(appRouter);

    // 8) 模块总线：外部地址与内部协议的统一入口。
    final moduleBus = ModuleBus(registry: registry, navigator: appRouter);
    locator
      ..registerSingleton<ModuleRegistry>(registry)
      ..registerSingleton<ModuleBus>(moduleBus);

    // 9) 应用级反应：模块只负责宣布「发生了什么」，响应方式由应用决定。
    final subscriptions = <void Function()>[
      // 9a) 主流程：登录成功 → 记录用户 → 进入首页。
      eventBus.subscribe<LoginSucceededEvent>((event) async {
        final session = event.session;
        observability.logger.info(
          '登录成功',
          context: <String, Object?>{'account': session.account},
        );
        await observability.setUserId(session.account);
        await appRouter.go('/home');
      }),
      // 9b) 独立的埋点订阅者：认证模块并不知道它存在，这正是 EventBus
      //     相对直接调用的价值。
      eventBus.subscribe<LoginSucceededEvent>((event) {
        unawaited(
          observability.analytics.track(
            'login_succeeded',
            properties: <String, Object?>{
              'method': event.session.method.name,
            },
          ),
        );
      }),
      // 9c) 退出登录：清会话 → 断开用户关联 → 回登录页。
      eventBus.subscribe<LogoutRequestedEvent>((event) async {
        sessionStore.clear();
        observability.logger.info('用户退出登录');
        await observability.setUserId(null);
        await observability.analytics.track('logout');
        await appRouter.go('/login');
      }),
    ];

    // 10) 外部深链：与内部 `moduleBus.open('product://...')` 完全同源。
    if (deepLink != null && deepLink.isNotEmpty) {
      final response = await moduleBus.open(deepLink);
      if (response case FailureResponse(:final error)) {
        observability.logger.warn('深链无法处理：$deepLink', error: error);
      }
    }

    return Bootstrap._(
      config: appConfig,
      locator: locator,
      observability: observability,
      eventBus: eventBus,
      registry: registry,
      appRouter: appRouter,
      moduleBus: moduleBus,
      sessionStore: sessionStore,
      subscriptions: subscriptions,
    );
  }

  /// 演示环境的基础设施：本地假数据源。
  ///
  /// 接入真实后端时，把这里换成实现 [AuthService] 的 HTTP 数据源即可，
  /// UI、Controller 与模块装配都不需要改动。
  static void registerDemoInfrastructure(ServiceLocator locator) {
    locator.registerLazySingleton<AuthService>(FakeAuthService.new);
  }

  /// 生效的配置。
  final AppConfig config;

  /// 依赖容器。
  final ServiceLocator locator;

  /// 可观测性门面。
  final Observability observability;

  /// 跨模块事件总线。
  final EventBus eventBus;

  /// 模块注册表（启动日志与排障用）。
  final ModuleRegistry registry;

  /// 由模块拼装出来的路由器。
  final AppRouter appRouter;

  /// 模块总线。
  final ModuleBus moduleBus;

  /// 会话状态。
  final SessionStore sessionStore;

  /// 应用级事件订阅的取消函数，[dispose] 时统一释放。
  final List<void Function()> subscriptions;

  bool _disposed = false;

  /// 释放订阅与路由资源。
  ///
  /// 幂等：`ModuleApp` 卸载时会调用它，而测试或上层也可能再调一次——
  /// 重复 dispose 会让 go_router 抛「used after being disposed」。
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final unsubscribe in subscriptions) {
      unsubscribe();
    }
    sessionStore.dispose();
    appRouter.dispose();
  }
}
