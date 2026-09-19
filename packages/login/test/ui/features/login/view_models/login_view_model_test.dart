import 'package:flutter_test/flutter_test.dart';
import 'package:login/login.dart';

void main() {
  late AuthRepository repository;

  setUp(() {
    repository = AuthRepository(FakeAuthService(latency: Duration.zero));
  });

  group('LoginViewModel 基础状态', () {
    test('默认使用密码登录', () {
      final viewModel = LoginViewModel(repository);
      expect(viewModel.mode.value, LoginMode.password);
      viewModel.dispose();
    });

    test('密码显隐切换', () {
      final viewModel = LoginViewModel(repository);
      expect(viewModel.obscurePassword.value, isTrue);
      viewModel.togglePasswordVisibility();
      expect(viewModel.obscurePassword.value, isFalse);
      viewModel.dispose();
    });

    test('切换登录方式会清空上一次的字段错误', () async {
      final viewModel = LoginViewModel(repository);
      await viewModel.submit();
      expect(viewModel.passwordError.value, '请输入密码');

      viewModel.switchMode(LoginMode.smsCode);
      expect(viewModel.mode.value, LoginMode.smsCode);
      expect(viewModel.passwordError.value, isNull);
      expect(viewModel.smsCodeError.value, isNull);
      viewModel.dispose();
    });

    test('修改输入会清除对应错误', () async {
      final viewModel = LoginViewModel(repository);
      await viewModel.submit();
      expect(viewModel.accountError.value, isNotNull);

      viewModel.updateAccount('demo');
      expect(viewModel.accountError.value, isNull);

      viewModel.updatePassword('abc123');
      expect(viewModel.passwordError.value, isNull);
      viewModel.dispose();
    });
  });

  group('LoginViewModel 密码登录校验', () {
    test('空输入提交时给出账号与密码错误', () async {
      final viewModel = LoginViewModel(repository);
      final session = await viewModel.submit();

      expect(session, isNull);
      expect(viewModel.accountError.value, '请输入账号');
      expect(viewModel.passwordError.value, '请输入密码');
      expect(viewModel.errorMessage.value, isNull);
      viewModel.dispose();
    });

    test('手机号非法时给出手机号错误', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..updateAccount('12345')
        ..updatePassword('abc123');

      await viewModel.submit();
      expect(viewModel.accountError.value, '手机号格式不正确');
      expect(viewModel.passwordError.value, isNull);
      viewModel.dispose();
    });

    test('邮箱非法时给出邮箱错误', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..updateAccount('user@')
        ..updatePassword('abc123');

      await viewModel.submit();
      expect(viewModel.accountError.value, '邮箱格式不正确');
      viewModel.dispose();
    });

    test('昵称超过 30 字符时被拦截', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..updateAccount('a' * 31)
        ..updatePassword('abc123');

      await viewModel.submit();
      expect(viewModel.accountError.value, '昵称长度不能超过 30 个字符');
      viewModel.dispose();
    });

    test('密码超过 30 位时被拦截', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..updateAccount('demo')
        ..updatePassword('a' * 31);

      await viewModel.submit();
      expect(viewModel.passwordError.value, '密码长度不能超过 30 位');
      viewModel.dispose();
    });

    test('密码登录成功返回会话', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..updateAccount('demo')
        ..updatePassword(FakeAuthService.defaultPassword);

      final session = await viewModel.submit();
      expect(session, isNotNull);
      expect(session!.account, 'demo');
      expect(session.method, LoginMethod.password);
      expect(viewModel.isSubmitting.value, isFalse);
      viewModel.dispose();
    });

    test('账号不存在时在账号输入框给出明确提示', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..updateAccount('nobody')
        ..updatePassword('abc123');

      final session = await viewModel.submit();
      expect(session, isNull);
      expect(viewModel.accountError.value, '账号不存在，请检查账号是否正确');
      expect(viewModel.passwordError.value, isNull);
      expect(viewModel.errorMessage.value, isNull);
      viewModel.dispose();
    });

    test('密码错误时在密码输入框给出明确提示', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..updateAccount('demo')
        ..updatePassword('wrong123');

      final session = await viewModel.submit();
      expect(session, isNull);
      expect(viewModel.passwordError.value, '密码错误，请重新输入');
      expect(viewModel.accountError.value, isNull);
      expect(viewModel.errorMessage.value, isNull);
      viewModel.dispose();
    });
  });

  group('LoginViewModel 验证码登录', () {
    test('空验证码提交时给出验证码错误', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..switchMode(LoginMode.smsCode)
        ..updateAccount('demo');

      final session = await viewModel.submit();
      expect(session, isNull);
      expect(viewModel.smsCodeError.value, '请输入短信验证码');
      expect(viewModel.passwordError.value, isNull);
      viewModel.dispose();
    });

    test('验证码登录完整流程', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..switchMode(LoginMode.smsCode)
        ..updateAccount(FakeAuthService.demoAccount);

      final sent = await viewModel.sendSmsCode();
      expect(sent, isTrue);
      expect(viewModel.debugSmsCode.value, FakeAuthService.smsCode);

      viewModel.updateSmsCode(FakeAuthService.smsCode);
      final session = await viewModel.submit();
      expect(session, isNotNull);
      expect(session!.method, LoginMethod.smsCode);
      viewModel.dispose();
    });

    test('未发送验证码直接登录会在验证码输入框提示失效', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..switchMode(LoginMode.smsCode)
        ..updateAccount('demo')
        ..updateSmsCode('123456');

      final session = await viewModel.submit();
      expect(session, isNull);
      expect(viewModel.smsCodeError.value, '验证码错误或已失效，请重新获取');
      expect(viewModel.errorMessage.value, isNull);
      viewModel.dispose();
    });

    test('账号不存在时在账号输入框提示', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..switchMode(LoginMode.smsCode)
        ..updateAccount('nobody');

      final sent = await viewModel.sendSmsCode();
      expect(sent, isFalse);
      expect(viewModel.accountError.value, '账号不存在，请检查账号是否正确');
      expect(viewModel.errorMessage.value, isNull);
      viewModel.dispose();
    });

    test('账号非法时无法发送验证码', () async {
      final viewModel = LoginViewModel(repository);
      viewModel
        ..switchMode(LoginMode.smsCode)
        ..updateAccount('12345');

      final sent = await viewModel.sendSmsCode();
      expect(sent, isFalse);
      expect(viewModel.accountError.value, '手机号格式不正确');
      expect(viewModel.debugSmsCode.value, isNull);
      viewModel.dispose();
    });

    test('发送验证码后进入倒计时并最终归零', () async {
      final viewModel = LoginViewModel(
        repository,
        resendSeconds: 2,
        tick: const Duration(milliseconds: 5),
      );
      viewModel.updateAccount('demo');

      await viewModel.sendSmsCode();
      expect(viewModel.countdownSeconds.value, 2);
      expect(viewModel.isSendingCode.value, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(viewModel.countdownSeconds.value, 0);
      viewModel.dispose();
    });

    test('倒计时期间 dispose 不会抛异常', () async {
      final viewModel = LoginViewModel(
        repository,
        resendSeconds: 2,
        tick: const Duration(milliseconds: 5),
      );
      viewModel.updateAccount('demo');
      await viewModel.sendSmsCode();

      viewModel.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
  });

  group('LoginViewModel signals 语义', () {
    test('isPasswordMode 由 mode 派生', () {
      final viewModel = LoginViewModel(repository);
      expect(viewModel.isPasswordMode.value, isTrue);

      viewModel.switchMode(LoginMode.smsCode);
      expect(viewModel.isPasswordMode.value, isFalse);
      viewModel.dispose();
    });

    test('canSendCode 在倒计时前后自动变化', () async {
      final viewModel = LoginViewModel(
        repository,
        resendSeconds: 1,
        tick: const Duration(milliseconds: 5),
      );
      expect(viewModel.canSendCode.value, isTrue);

      viewModel.updateAccount('demo');
      await viewModel.sendSmsCode();
      expect(viewModel.canSendCode.value, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(viewModel.countdownSeconds.value, 0);
      expect(viewModel.canSendCode.value, isTrue);
      viewModel.dispose();
    });

    test('相同值不会重复通知（signals 内置相等性判断）', () {
      final viewModel = LoginViewModel(repository);
      final seen = <String?>[];
      final unsubscribe = viewModel.account.subscribe(seen.add);

      viewModel.updateAccount('demo');
      viewModel.updateAccount('demo');

      // subscribe 会立即回放一次当前值（初始为空串），重复写入被相等性判断跳过。
      expect(seen, <String>['', 'demo']);
      unsubscribe();
      viewModel.dispose();
    });
  });
}
