import 'package:core_session/core_session.dart';

import '../../domain/entities/sms_code_receipt.dart';

/// 认证数据源端口：屏蔽具体后端实现（HTTP / 本地假实现）。
///
/// 该端口由**应用组装根**实现并注入：生产环境接真实后端，测试与演示用
/// `package:feature_auth/testing.dart` 里的假实现替换。
abstract interface class AuthService {
  /// 使用账号 + 密码登录。
  ///
  /// 账号不存在或密码错误时抛出 AuthException。
  Future<AuthSession> loginWithPassword({
    required String account,
    required String password,
  });

  /// 使用账号 + 短信验证码登录。
  Future<AuthSession> loginWithSmsCode({
    required String account,
    required String smsCode,
  });

  /// 向 [account] 发送短信验证码。
  Future<SmsCodeReceipt> sendSmsCode({required String account});

  /// 重置密码：校验短信验证码后写入新密码。
  Future<void> resetPassword({
    required String account,
    required String smsCode,
    required String newPassword,
  });
}
