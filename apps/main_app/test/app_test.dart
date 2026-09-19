import 'package:core_config/core_config.dart';
import 'package:core_di/core_di.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_auth/testing.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_app/bootstrap.dart';
import 'package:main_app/src/app.dart';

/// 端到端测试：走真实的装配流程（Bootstrap → ModuleRegistry → 模块路由 →
/// EventBus → 跳转），只把数据源换成零延迟的假实现。
///
/// 每个用例都会 `Bootstrap.run` 一次，拿到**独立**的 `ServiceLocator`
/// 容器，因此不再需要 get_it 的全局 reset，用例之间也不会互相污染。
void main() {
  const testConfig = AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: 'https://api.test',
  );

  Future<Bootstrap> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final bootstrap = await Bootstrap.run(
      config: testConfig,
      registerInfrastructure: (ServiceLocator locator) =>
          locator.registerLazySingleton<AuthService>(
            () => FakeAuthService(latency: Duration.zero),
          ),
    );

    await tester.pumpWidget(ModuleApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();
    return bootstrap;
  }

  testWidgets('默认进入密码登录页，登录成功后跳转首页并可退出', (tester) async {
    final bootstrap = await pumpApp(tester);
    addTearDown(bootstrap.dispose);

    expect(find.text('欢迎登录'), findsOneWidget);
    expect(find.text('密码登录'), findsOneWidget);
    expect(find.text('验证码登录'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_account_field')),
      FakeAuthService.demoAccount,
    );
    // 先输入错误密码，验证给出明确提示且停留在登录页。
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'wrong123',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('密码错误，请重新输入'), findsOneWidget);
    expect(find.text('欢迎登录'), findsOneWidget);

    // 再输入正确密码即可登录成功。
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      FakeAuthService.defaultPassword,
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('你好，demo'), findsOneWidget);
    expect(find.text('已登录 · 密码登录'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('home_logout_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_logout_tile')));
    await tester.pumpAndSettle();

    expect(find.text('欢迎登录'), findsOneWidget);
  });

  testWidgets('登录页可跳转重置密码页并通过 iOS 返回按钮返回', (tester) async {
    final bootstrap = await pumpApp(tester);
    addTearDown(bootstrap.dispose);

    await tester.tap(find.byKey(const Key('login_forgot_password_button')));
    await tester.pumpAndSettle();

    expect(find.text('设置新密码'), findsOneWidget);
    expect(find.byKey(const Key('reset_account_field')), findsOneWidget);
    expect(
      find.byKey(const Key('reset_confirm_password_field')),
      findsOneWidget,
    );

    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();

    expect(find.text('欢迎登录'), findsOneWidget);
  });

  testWidgets('验证码登录成功后跳转首页', (tester) async {
    final bootstrap = await pumpApp(tester);
    addTearDown(bootstrap.dispose);

    await tester.tap(find.text('验证码登录'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('login_account_field')),
      'demo',
    );
    await tester.tap(find.byKey(const Key('login_send_code_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.enterText(
      find.byKey(const Key('login_sms_code_field')),
      FakeAuthService.smsCode,
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('你好，demo'), findsOneWidget);
    expect(find.text('已登录 · 验证码登录'), findsOneWidget);
  });

  testWidgets('深链经 Module Protocol 直达首页', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    // 外部入口（推送 / 深链）与内部协议共用同一套地址。
    final bootstrap = await Bootstrap.run(
      config: testConfig,
      deepLink: 'home://root',
      registerInfrastructure: (ServiceLocator locator) =>
          locator.registerLazySingleton<AuthService>(
            () => FakeAuthService(latency: Duration.zero),
          ),
    );
    addTearDown(bootstrap.dispose);

    await tester.pumpWidget(ModuleApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets('无法处理的深链不阻塞启动', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final bootstrap = await Bootstrap.run(
      config: testConfig,
      deepLink: 'unknown://thing',
      registerInfrastructure: (ServiceLocator locator) =>
          locator.registerLazySingleton<AuthService>(
            () => FakeAuthService(latency: Duration.zero),
          ),
    );
    addTearDown(bootstrap.dispose);

    await tester.pumpWidget(ModuleApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    // 退回默认起始位置。
    expect(find.text('欢迎登录'), findsOneWidget);
  });
}
