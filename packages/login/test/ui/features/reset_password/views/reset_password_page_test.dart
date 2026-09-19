import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/login.dart';

import '../../../../helpers/test_harness.dart';

void main() {
  late AuthRepository repository;

  setUp(() {
    repository = buildAuthRepository();
  });

  Future<void> pumpResetPage(
    WidgetTester tester, {
    VoidCallback? onResetSuccess,
  }) async {
    await tester.pumpWidget(
      wrapWithCupertinoApp(
        ResetPasswordPage(
          repository: repository,
          demoHintText: '演示环境',
          onResetSuccess: onResetSuccess,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('展示重置密码表单的四个输入项', (tester) async {
    useTallSurface(tester);
    await pumpResetPage(tester);

    expect(find.text('重置密码'), findsOneWidget);
    expect(find.text('设置新密码'), findsOneWidget);
    expect(find.byKey(const Key('reset_account_field')), findsOneWidget);
    expect(find.byKey(const Key('reset_sms_code_field')), findsOneWidget);
    expect(find.byKey(const Key('reset_new_password_field')), findsOneWidget);
    expect(
      find.byKey(const Key('reset_confirm_password_field')),
      findsOneWidget,
    );
    expect(find.text('获取验证码'), findsOneWidget);
  });

  testWidgets('空表单提交展示四项校验提示', (tester) async {
    useTallSurface(tester);
    await pumpResetPage(tester);

    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await settleAsync(tester);

    expect(find.text('请输入账号'), findsOneWidget);
    expect(find.text('请输入短信验证码'), findsOneWidget);
    expect(find.text('请输入新密码'), findsOneWidget);
    expect(find.text('请再次输入密码'), findsOneWidget);
  });

  testWidgets('新密码不合规且两次不一致时展示对应提示', (tester) async {
    useTallSurface(tester);
    await pumpResetPage(tester);

    await tester.enterText(
      find.byKey(const Key('reset_account_field')),
      'demo',
    );
    await tester.enterText(
      find.byKey(const Key('reset_sms_code_field')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const Key('reset_new_password_field')),
      'abcdef',
    );
    await tester.enterText(
      find.byKey(const Key('reset_confirm_password_field')),
      'abcde1',
    );
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await settleAsync(tester);

    expect(find.text('密码必须同时包含字母和数字'), findsOneWidget);
    expect(find.text('两次输入的密码不一致'), findsOneWidget);
  });

  testWidgets('账号非法时点击获取验证码展示手机号错误', (tester) async {
    useTallSurface(tester);
    await pumpResetPage(tester);

    await tester.enterText(
      find.byKey(const Key('reset_account_field')),
      '12345',
    );
    await tester.tap(find.byKey(const Key('reset_send_code_button')));
    await settleAsync(tester);

    expect(find.text('手机号格式不正确'), findsOneWidget);
  });

  testWidgets('完整重置流程：获取验证码 → 提交 → 成功弹窗 → 回调', (tester) async {
    useTallSurface(tester);
    var resetDone = false;
    await pumpResetPage(tester, onResetSuccess: () => resetDone = true);

    await tester.enterText(
      find.byKey(const Key('reset_account_field')),
      'demo',
    );
    await tester.tap(find.byKey(const Key('reset_send_code_button')));
    await settleAsync(tester);

    expect(find.textContaining('123456'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reset_sms_code_field')),
      FakeAuthService.smsCode,
    );
    await tester.enterText(
      find.byKey(const Key('reset_new_password_field')),
      'newpass1',
    );
    await tester.enterText(
      find.byKey(const Key('reset_confirm_password_field')),
      'newpass1',
    );
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await settleAsync(tester);

    expect(find.text('重置成功'), findsOneWidget);

    await tester.tap(find.text('返回登录'));
    await settleAsync(tester);
    expect(resetDone, isTrue);

    // 重置成功后新密码可登录。
    final session = await repository.loginWithPassword(
      account: 'demo',
      password: 'newpass1',
    );
    expect(session.account, 'demo');

    await unmount(tester);
  });

  testWidgets('验证码错误时展示服务端错误', (tester) async {
    useTallSurface(tester);
    await pumpResetPage(tester);

    await tester.enterText(
      find.byKey(const Key('reset_account_field')),
      'demo',
    );
    await tester.enterText(
      find.byKey(const Key('reset_sms_code_field')),
      '000000',
    );
    await tester.enterText(
      find.byKey(const Key('reset_new_password_field')),
      'newpass1',
    );
    await tester.enterText(
      find.byKey(const Key('reset_confirm_password_field')),
      'newpass1',
    );
    await tester.tap(find.byKey(const Key('reset_submit_button')));
    await settleAsync(tester);

    expect(find.text('验证码错误或已失效，请重新获取'), findsOneWidget);
  });

  testWidgets('账号不存在时获取验证码给出明确提示', (tester) async {
    useTallSurface(tester);
    await pumpResetPage(tester);

    await tester.enterText(
      find.byKey(const Key('reset_account_field')),
      'nobody',
    );
    await tester.tap(find.byKey(const Key('reset_send_code_button')));
    await settleAsync(tester);

    expect(find.text('账号不存在，请检查账号是否正确'), findsOneWidget);
  });

  testWidgets('iPhone 尺寸下重置密码页可滚动且无布局异常', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpResetPage(tester);
    expect(tester.takeException(), isNull);

    final rect = tester.getRect(find.byKey(const Key('reset_scroll_view')));
    await tester.dragFrom(
      Offset(rect.left + 20, rect.bottom - 20),
      const Offset(0, -200),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('reset_submit_button')), findsOneWidget);
  });
}
