import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:home/home.dart';
import 'package:login/login.dart';
import 'package:signals/signals_flutter.dart';

/// 全局依赖容器。
final GetIt getIt = GetIt.instance;

/// 演示环境提示（演示账号与默认密码）。
const String _demoHintText = '演示环境：演示账号 demo，默认密码 abc123';

void main() {
  configureDependencies();
  runApp(const ModuleApp());
}

/// 注册依赖；[authService] 仅用于测试替换数据源。
void configureDependencies({AuthService? authService}) {
  getIt
    ..registerLazySingleton<AuthService>(() => authService ?? FakeAuthService())
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepository(getIt<AuthService>()),
    );
}

/// 应用根组件：iOS 风格 + go_router 声明式路由。
class ModuleApp extends StatefulWidget {
  /// 创建应用根组件。
  const ModuleApp({super.key});

  @override
  State<ModuleApp> createState() => _ModuleAppState();
}

class _ModuleAppState extends State<ModuleApp> {
  /// app 级会话状态：用 signal 承载，路由 builder 用 [SignalBuilder] 订阅，
  /// 不需要 setState 把整棵应用树标记为脏。
  final _session = signal<AuthSession?>(null);

  // CupertinoApp 下 go_router 会自动使用 CupertinoPage（iOS 转场）。
  late final GoRouter _router = GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(path: '/', redirect: (context, state) => '/login'),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginPage(
          repository: getIt<AuthRepository>(),
          demoHintText: _demoHintText,
          onLoginSuccess: _handleLoginSuccess,
          onForgotPassword: () => _router.push('/reset-password'),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => ResetPasswordPage(
          repository: getIt<AuthRepository>(),
          demoHintText: _demoHintText,
          onResetSuccess: _backToLogin,
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => SignalBuilder(
          builder: (context) => HomePage(
            account: _session.value?.account ?? '',
            loginMethodLabel: _loginMethodLabel(_session.value?.method),
            onLogout: _handleLogout,
          ),
        ),
      ),
    ],
    errorBuilder: (context, state) =>
        _RouteErrorPage(message: '${state.error}'),
  );

  void _handleLoginSuccess(AuthSession session) {
    _session.value = session;
    _router.go('/home');
  }

  void _handleLogout() {
    _session.value = null;
    _router.go('/login');
  }

  void _backToLogin() {
    if (_router.canPop()) {
      _router.pop();
    } else {
      _router.go('/login');
    }
  }

  String? _loginMethodLabel(LoginMethod? method) => switch (method) {
    LoginMethod.password => '密码登录',
    LoginMethod.smsCode => '验证码登录',
    null => null,
  };

  @override
  void dispose() {
    _session.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp.router(
      title: '模块化应用',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemBlue,
      ),
      routerConfig: _router,
    );
  }
}

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('页面不存在')),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
