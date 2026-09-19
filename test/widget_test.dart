import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/login.dart';
import 'package:module/main.dart';

void main() {
  setUp(() async {
    // get_it 9 的 reset() 是异步的，必须等待，否则会与随后的注册竞争。
    await getIt.reset();
    configureDependencies(authService: FakeAuthService(latency: Duration.zero));
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ModuleApp());
    await tester.pumpAndSettle();
  }

  testWidgets('默认进入密码登录页，登录成功后跳转首页并可退出', (tester) async {
    await pumpApp(tester);

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
    await pumpApp(tester);

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
    await pumpApp(tester);

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
}
