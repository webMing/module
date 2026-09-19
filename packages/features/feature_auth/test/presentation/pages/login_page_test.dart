import 'package:core_session/core_session.dart';
import 'package:feature_auth/src/data/datasources/fake_auth_service.dart';
import 'package:feature_auth/src/domain/repositories/auth_repository.dart';
import 'package:feature_auth/src/presentation/pages/login_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_harness.dart';

void main() {
  late AuthRepository repository;

  setUp(() {
    repository = buildAuthRepository();
  });

  testWidgets('默认展示密码登录表单', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(repository: repository, onLoginSuccess: (_) {}),
      ),
    );

    expect(find.text('欢迎登录'), findsOneWidget);
    expect(find.text('密码登录'), findsOneWidget);
    expect(find.text('验证码登录'), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_sms_code_field')), findsNothing);
    // 未提供 onForgotPassword 时不展示入口。
    expect(find.text('忘记密码？'), findsNothing);
  });

  testWidgets('可以切换到验证码登录', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(repository: repository, onLoginSuccess: (_) {}),
      ),
    );

    await tester.tap(find.text('验证码登录'));
    await tester.pump();

    expect(find.byKey(const Key('login_sms_code_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsNothing);
    expect(find.text('获取验证码'), findsOneWidget);
  });

  testWidgets('空表单提交展示校验提示', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(repository: repository, onLoginSuccess: (_) {}),
      ),
    );

    await tester.tap(find.byKey(const Key('login_submit_button')));
    await settleAsync(tester);

    expect(find.text('请输入账号'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
  });

  testWidgets('手机号非法时展示手机号错误', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(repository: repository, onLoginSuccess: (_) {}),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login_account_field')),
      '12345',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'abc123',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await settleAsync(tester);

    expect(find.text('手机号格式不正确'), findsOneWidget);
  });

  testWidgets('昵称超过 30 字符时被拦截', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(repository: repository, onLoginSuccess: (_) {}),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login_account_field')),
      '张' * 31,
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'abc123',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await settleAsync(tester);

    expect(find.text('昵称长度不能超过 30 个字符'), findsOneWidget);
  });

  testWidgets('密码登录成功后回调会话', (tester) async {
    useTallSurface(tester);
    AuthSession? captured;
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(
          repository: repository,
          onLoginSuccess: (session) => captured = session,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login_account_field')),
      'demo',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      FakeAuthService.defaultPassword,
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await settleAsync(tester);

    expect(captured, isNotNull);
    expect(captured!.account, 'demo');
    expect(captured!.method, LoginMethod.password);
  });

  testWidgets('账号不存在时在账号输入框给出明确提示', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(repository: repository, onLoginSuccess: (_) {}),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login_account_field')),
      'nobody',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      FakeAuthService.defaultPassword,
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await settleAsync(tester);

    expect(find.text('账号不存在，请检查账号是否正确'), findsOneWidget);
  });

  testWidgets('密码错误时在密码输入框给出明确提示', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(repository: repository, onLoginSuccess: (_) {}),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login_account_field')),
      FakeAuthService.demoAccount,
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'wrong123',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await settleAsync(tester);

    expect(find.text('密码错误，请重新输入'), findsOneWidget);
  });

  testWidgets('点击忘记密码触发跳转回调', (tester) async {
    useTallSurface(tester);
    var forgotTapped = false;
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(
          repository: repository,
          onLoginSuccess: (_) {},
          onForgotPassword: () => forgotTapped = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('login_forgot_password_button')));
    await tester.pump();

    expect(forgotTapped, isTrue);
  });

  testWidgets('验证码登录：获取验证码 → 输入验证码 → 登录成功', (tester) async {
    useTallSurface(tester);
    AuthSession? captured;
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(
          repository: repository,
          onLoginSuccess: (session) => captured = session,
        ),
      ),
    );

    await tester.tap(find.text('验证码登录'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('login_account_field')),
      FakeAuthService.demoAccount,
    );

    await tester.tap(find.byKey(const Key('login_send_code_button')));
    await settleAsync(tester);

    // 演示环境会回显验证码明文。
    expect(find.textContaining('123456'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_sms_code_field')),
      FakeAuthService.smsCode,
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await settleAsync(tester);

    expect(captured, isNotNull);
    expect(captured!.method, LoginMethod.smsCode);
    expect(captured!.account, FakeAuthService.demoAccount);

    await unmount(tester);
  });

  testWidgets('未获取验证码时登录会提示验证码失效', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(repository: repository, onLoginSuccess: (_) {}),
      ),
    );

    await tester.tap(find.text('验证码登录'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('login_account_field')),
      'demo',
    );
    await tester.enterText(
      find.byKey(const Key('login_sms_code_field')),
      '000000',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await settleAsync(tester);

    expect(find.text('验证码错误或已失效，请重新获取'), findsOneWidget);
  });

  testWidgets('iPhone 尺寸下两种登录方式都不出现布局异常', (tester) async {
    // iPhone 13：1170x2532 @3 → 390x844 逻辑像素
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWithCupertinoApp(
        LoginPage(repository: repository, onLoginSuccess: (_) {}),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('验证码登录'));
    await tester.pump();
    final rect = tester.getRect(find.byKey(const Key('login_scroll_view')));
    await tester.dragFrom(
      Offset(rect.left + 20, rect.bottom - 20),
      const Offset(0, -200),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('login_sms_code_field')), findsOneWidget);
  });
}
