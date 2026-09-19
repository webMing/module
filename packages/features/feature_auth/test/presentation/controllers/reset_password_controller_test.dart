import 'package:feature_auth/src/data/datasources/fake_auth_service.dart';
import 'package:feature_auth/src/data/repositories/auth_repository_impl.dart';
import 'package:feature_auth/src/domain/repositories/auth_repository.dart';
import 'package:feature_auth/src/presentation/controllers/reset_password_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthRepository repository;

  setUp(() {
    repository = AuthRepositoryImpl(FakeAuthService(latency: Duration.zero));
  });

  group('ResetPasswordController 校验', () {
    test('空输入提交时给出全部字段错误', () async {
      final viewModel = ResetPasswordController(repository);
      final success = await viewModel.submit();

      expect(success, isFalse);
      expect(viewModel.accountError.value, '请输入账号');
      expect(viewModel.smsCodeError.value, '请输入短信验证码');
      expect(viewModel.newPasswordError.value, '请输入新密码');
      expect(viewModel.confirmPasswordError.value, '请再次输入密码');
      viewModel.dispose();
    });

    test('新密码长度不符合 6-30 位时被拦截', () async {
      final viewModel = ResetPasswordController(repository);
      viewModel
        ..updateAccount('demo')
        ..updateSmsCode('123456')
        ..updateNewPassword('abc12')
        ..updateConfirmPassword('abc12');

      expect(await viewModel.submit(), isFalse);
      expect(viewModel.newPasswordError.value, '密码长度需为 6-30 位');
      viewModel.dispose();
    });

    test('新密码未同时包含字母和数字时被拦截', () async {
      final viewModel = ResetPasswordController(repository);
      viewModel
        ..updateAccount('demo')
        ..updateSmsCode('123456')
        ..updateNewPassword('abcdef')
        ..updateConfirmPassword('abcdef');

      expect(await viewModel.submit(), isFalse);
      expect(viewModel.newPasswordError.value, '密码必须同时包含字母和数字');
      viewModel.dispose();
    });

    test('两次密码不一致时被拦截', () async {
      final viewModel = ResetPasswordController(repository);
      viewModel
        ..updateAccount('demo')
        ..updateSmsCode('123456')
        ..updateNewPassword('abc123')
        ..updateConfirmPassword('abc124');

      expect(await viewModel.submit(), isFalse);
      expect(viewModel.confirmPasswordError.value, '两次输入的密码不一致');
      viewModel.dispose();
    });

    test('账号非法时无法发送验证码', () async {
      final viewModel = ResetPasswordController(repository);
      viewModel.updateAccount('user@');

      expect(await viewModel.sendSmsCode(), isFalse);
      expect(viewModel.accountError.value, '邮箱格式不正确');
      viewModel.dispose();
    });
  });

  group('ResetPasswordController 提交流程', () {
    test('完整流程：发送验证码 → 重置成功 → 新密码可登录', () async {
      final viewModel = ResetPasswordController(repository);
      viewModel.updateAccount('demo');

      expect(await viewModel.sendSmsCode(), isTrue);
      expect(viewModel.debugSmsCode.value, FakeAuthService.smsCode);

      viewModel
        ..updateSmsCode(FakeAuthService.smsCode)
        ..updateNewPassword('newpass1')
        ..updateConfirmPassword('newpass1');

      expect(await viewModel.submit(), isTrue);
      expect(viewModel.isSubmitting.value, isFalse);

      final session = await repository.loginWithPassword(
        account: 'demo',
        password: 'newpass1',
      );
      expect(session.account, 'demo');
      viewModel.dispose();
    });

    test('验证码错误时写入表单错误', () async {
      final viewModel = ResetPasswordController(repository);
      viewModel.updateAccount('demo');
      await viewModel.sendSmsCode();

      viewModel
        ..updateSmsCode('000000')
        ..updateNewPassword('newpass1')
        ..updateConfirmPassword('newpass1');

      expect(await viewModel.submit(), isFalse);
      expect(viewModel.smsCodeError.value, '验证码错误或已失效，请重新获取');
      expect(viewModel.errorMessage.value, isNull);
      viewModel.dispose();
    });

    test('账号不存在时在账号输入框给出明确提示', () async {
      final viewModel = ResetPasswordController(repository);
      viewModel.updateAccount('nobody');

      expect(await viewModel.sendSmsCode(), isFalse);
      expect(viewModel.accountError.value, '账号不存在，请检查账号是否正确');
      expect(viewModel.errorMessage.value, isNull);
      viewModel.dispose();
    });

    test('确认密码显隐切换', () {
      final viewModel = ResetPasswordController(repository);
      expect(viewModel.obscureNewPassword.value, isTrue);
      expect(viewModel.obscureConfirmPassword.value, isTrue);

      viewModel
        ..toggleNewPasswordVisibility()
        ..toggleConfirmPasswordVisibility();
      expect(viewModel.obscureNewPassword.value, isFalse);
      expect(viewModel.obscureConfirmPassword.value, isFalse);
      viewModel.dispose();
    });

    test('倒计时期间 dispose 不会抛异常', () async {
      final viewModel = ResetPasswordController(
        repository,
        resendSeconds: 2,
        tick: const Duration(milliseconds: 5),
      );
      viewModel.updateAccount('demo');
      await viewModel.sendSmsCode();
      expect(viewModel.countdownSeconds.value, 2);

      viewModel.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
  });

  group('ResetPasswordController signals 语义', () {
    test('canSendCode 在倒计时前后自动变化', () async {
      final viewModel = ResetPasswordController(
        repository,
        resendSeconds: 1,
        tick: const Duration(milliseconds: 5),
      );
      expect(viewModel.canSendCode.value, isTrue);

      viewModel.updateAccount('demo');
      await viewModel.sendSmsCode();
      expect(viewModel.canSendCode.value, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(viewModel.canSendCode.value, isTrue);
      viewModel.dispose();
    });

    test('错误按字段独立存放，不污染表单级错误', () async {
      final viewModel = ResetPasswordController(repository);
      await viewModel.submit();

      expect(viewModel.accountError.value, isNotNull);
      expect(viewModel.newPasswordError.value, isNotNull);
      expect(viewModel.errorMessage.value, isNull);
      viewModel.dispose();
    });
  });
}
