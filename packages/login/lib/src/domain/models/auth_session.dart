import 'package:flutter/foundation.dart';

/// 登录方式。
enum LoginMethod {
  /// 账号 + 密码登录。
  password,

  /// 账号 + 短信验证码登录。
  smsCode,
}

/// 一次成功登录后产生的会话信息。
///
/// 该模型是 domain 层对外的干净模型，不包含任何接口原始字段。
@immutable
class AuthSession {
  /// 创建一个登录会话。
  const AuthSession({
    required this.account,
    required this.method,
    required this.loggedInAt,
    this.token,
  });

  /// 登录使用的账号（手机号 / 邮箱 / 昵称）。
  final String account;

  /// 本次登录使用的方式。
  final LoginMethod method;

  /// 登录成功的时间。
  final DateTime loggedInAt;

  /// 服务端下发的令牌，假实现中仅作占位。
  final String? token;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AuthSession &&
        other.account == account &&
        other.method == method &&
        other.loggedInAt == loggedInAt &&
        other.token == token;
  }

  @override
  int get hashCode => Object.hash(account, method, loggedInAt, token);

  @override
  String toString() =>
      'AuthSession(account: $account, method: $method, token: $token)';
}
