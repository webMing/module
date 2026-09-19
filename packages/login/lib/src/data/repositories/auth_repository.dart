import '../../domain/models/auth_session.dart';
import '../services/auth_service.dart';

/// 认证仓库：UI 层唯一的数据入口。
///
/// 负责账号输入的归一化（去空格），并把数据源异常向上抛出。
class AuthRepository {
  /// 创建仓库，需要注入一个 [AuthService] 作为数据源。
  AuthRepository(this._service);

  final AuthService _service;

  /// 账号 + 密码登录。
  Future<AuthSession> loginWithPassword({
    required String account,
    required String password,
  }) {
    return _service.loginWithPassword(
      account: account.trim(),
      password: password,
    );
  }

  /// 账号 + 短信验证码登录。
  Future<AuthSession> loginWithSmsCode({
    required String account,
    required String smsCode,
  }) {
    return _service.loginWithSmsCode(
      account: account.trim(),
      smsCode: smsCode.trim(),
    );
  }

  /// 发送短信验证码。
  Future<SmsCodeReceipt> sendSmsCode({required String account}) {
    return _service.sendSmsCode(account: account.trim());
  }

  /// 重置密码。
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
