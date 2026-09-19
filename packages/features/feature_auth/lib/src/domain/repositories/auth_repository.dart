import 'package:core_session/core_session.dart';

import '../entities/sms_code_receipt.dart';

/// 认证仓库端口：presentation 层唯一的数据入口。
///
/// 端口只声明能力，不关心数据来自 HTTP 还是本地假数据；默认实现见 data 层的
/// `AuthRepositoryImpl`。账号与验证码的归一化（去空格）由实现负责。
abstract interface class AuthRepository {
  /// 账号 + 密码登录。
  Future<AuthSession> loginWithPassword({
    required String account,
    required String password,
  });

  /// 账号 + 短信验证码登录。
  Future<AuthSession> loginWithSmsCode({
    required String account,
    required String smsCode,
  });

  /// 发送短信验证码。
  Future<SmsCodeReceipt> sendSmsCode({required String account});

  /// 重置密码。
  Future<void> resetPassword({
    required String account,
    required String smsCode,
    required String newPassword,
  });
}
