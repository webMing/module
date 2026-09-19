import 'package:core_session/core_session.dart';
import 'package:feature_auth/src/data/datasources/fake_auth_service.dart';
import 'package:feature_auth/src/data/repositories/auth_repository_impl.dart';
import 'package:feature_auth/src/domain/services/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAuthService service;
  late AuthRepositoryImpl repository;

  setUp(() {
    service = FakeAuthService(latency: Duration.zero);
    repository = AuthRepositoryImpl(service);
  });

  test('密码登录会去除账号首尾空格', () async {
    final session = await repository.loginWithPassword(
      account: '  demo  ',
      password: FakeAuthService.defaultPassword,
    );

    expect(session.account, 'demo');
  });

  test('验证码登录会去除账号与验证码空格', () async {
    await repository.sendSmsCode(account: ' demo ');
    final session = await repository.loginWithSmsCode(
      account: 'demo ',
      smsCode: ' 123456 ',
    );

    expect(session.account, 'demo');
    expect(session.method, LoginMethod.smsCode);
  });

  test('重置密码后可用新密码登录，账号同样会被归一化', () async {
    await repository.sendSmsCode(account: 'demo');
    await repository.resetPassword(
      account: ' demo ',
      smsCode: ' 123456 ',
      newPassword: 'newpass1',
    );

    final session = await repository.loginWithPassword(
      account: 'demo',
      password: 'newpass1',
    );
    expect(session.account, 'demo');
  });

  test('数据源异常向上抛出', () async {
    await expectLater(
      repository.loginWithPassword(account: 'demo', password: 'bad123'),
      throwsA(isA<AuthException>()),
    );
  });
}
