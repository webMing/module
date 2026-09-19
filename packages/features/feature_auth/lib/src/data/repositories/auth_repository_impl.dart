import 'package:core_session/core_session.dart';

import '../../domain/entities/sms_code_receipt.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_service.dart';

/// 认证仓库实现：[AuthRepository] 端口的默认落地。
///
/// 负责账号输入的归一化（去空格），并把数据源异常向上抛出。
class AuthRepositoryImpl implements AuthRepository {
  /// 创建仓库，需要注入一个 [AuthService] 作为数据源。
  AuthRepositoryImpl(this._service);

  final AuthService _service;

  @override
  Future<AuthSession> loginWithPassword({
    required String account,
    required String password,
  }) {
    return _service.loginWithPassword(
      account: account.trim(),
      password: password,
    );
  }

  @override
  Future<AuthSession> loginWithSmsCode({
    required String account,
    required String smsCode,
  }) {
    return _service.loginWithSmsCode(
      account: account.trim(),
      smsCode: smsCode.trim(),
    );
  }

  @override
  Future<SmsCodeReceipt> sendSmsCode({required String account}) {
    return _service.sendSmsCode(account: account.trim());
  }

  @override
  Future<void> resetPassword({
    required String account,
    required String smsCode,
    required String newPassword,
  }) {
    return _service.resetPassword(
      account: account.trim(),
      smsCode: smsCode.trim(),
      newPassword: newPassword,
    );
  }
}
