import 'package:flutter_test/flutter_test.dart';
import 'package:login/login.dart';

void main() {
  late FakeAuthService service;

  setUp(() {
    service = FakeAuthService(latency: Duration.zero);
  });

  group('loginWithPassword', () {
    test('演示账号可用默认密码登录', () async {
      final session = await service.loginWithPassword(
        account: FakeAuthService.demoAccount,
        password: FakeAuthService.defaultPassword,
      );

      expect(session.account, 'demo');
      expect(session.method, LoginMethod.password);
    });

    test('账号不存在时抛出明确的 AuthException', () async {
      await expectLater(
        service.loginWithPassword(account: 'nobody', password: 'abc123'),
        throwsA(
          isA<AuthException>()
              .having((error) => error.message, 'message', '账号不存在，请检查账号是否正确')
              .having(
                (error) => error.code,
                'code',
                AuthErrorCode.accountNotFound,
              ),
        ),
      );
    });

    test('密码错误时抛出明确的 AuthException', () async {
      await expectLater(
        service.loginWithPassword(
          account: FakeAuthService.demoAccount,
          password: 'wrong123',
        ),
        throwsA(
          isA<AuthException>()
              .having((error) => error.message, 'message', '密码错误，请重新输入')
              .having(
                (error) => error.code,
                'code',
                AuthErrorCode.wrongPassword,
              ),
        ),
      );
    });
  });

  group('sendSmsCode / loginWithSmsCode', () {
    test('未发送验证码时登录失败', () async {
      await expectLater(
        service.loginWithSmsCode(account: 'demo', smsCode: '123456'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.code,
            'code',
            AuthErrorCode.smsCodeInvalid,
          ),
        ),
      );
    });

    test('账号不存在时无法发送验证码', () async {
      await expectLater(
        service.sendSmsCode(account: 'nobody'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.code,
            'code',
            AuthErrorCode.accountNotFound,
          ),
        ),
      );
    });

    test('发送后可用验证码登录', () async {
      final receipt = await service.sendSmsCode(account: 'demo');
      expect(receipt.debugCode, FakeAuthService.smsCode);

      final session = await service.loginWithSmsCode(
        account: 'demo',
        smsCode: FakeAuthService.smsCode,
      );
      expect(session.account, 'demo');
      expect(session.method, LoginMethod.smsCode);
    });

    test('验证码错误时登录失败', () async {
      await service.sendSmsCode(account: 'demo');
      await expectLater(
        service.loginWithSmsCode(account: 'demo', smsCode: '000000'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            '验证码错误或已失效，请重新获取',
          ),
        ),
      );
    });
  });

  group('resetPassword', () {
    test('验证码正确时重置成功，旧密码失效', () async {
      await service.sendSmsCode(account: 'demo');
      await service.resetPassword(
        account: 'demo',
        smsCode: FakeAuthService.smsCode,
        newPassword: 'newpass1',
      );

      final session = await service.loginWithPassword(
        account: 'demo',
        password: 'newpass1',
      );
      expect(session.account, 'demo');

      await expectLater(
        service.loginWithPassword(
          account: 'demo',
          password: FakeAuthService.defaultPassword,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('验证码错误时重置失败', () async {
      await service.sendSmsCode(account: 'demo');
      await expectLater(
        service.resetPassword(
          account: 'demo',
          smsCode: '999999',
          newPassword: 'newpass1',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('验证码不可重复使用', () async {
      await service.sendSmsCode(account: 'demo');
      await service.resetPassword(
        account: 'demo',
        smsCode: FakeAuthService.smsCode,
        newPassword: 'newpass1',
      );

      await expectLater(
        service.resetPassword(
          account: 'demo',
          smsCode: FakeAuthService.smsCode,
          newPassword: 'newpass2',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
