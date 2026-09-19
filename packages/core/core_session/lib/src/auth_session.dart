import 'package:core_model/core_model.dart';
import 'package:meta/meta.dart';

import 'login_method.dart';

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

  /// 从持久化 JSON 还原会话。
  ///
  /// [account] / [method] / [loggedInAt] 为必填，缺失即视为数据损坏并抛出
  /// [FormatException]，由调用方决定丢弃。
  factory AuthSession.fromJson(JsonMap json) {
    final rawLoggedInAt = json.requireString('loggedInAt');
    final loggedInAt = DateTime.tryParse(rawLoggedInAt);
    if (loggedInAt == null) {
      throw FormatException('loggedInAt 不是合法时间：$rawLoggedInAt', json);
    }
    return AuthSession(
      account: json.requireString('account'),
      method: LoginMethod.parse(json.requireString('method')),
      loggedInAt: loggedInAt,
      token: json.readString('token'),
    );
  }

  /// 登录使用的账号（手机号 / 邮箱 / 昵称）。
  final String account;

  /// 本次登录使用的方式。
  final LoginMethod method;

  /// 登录成功的时间。
  final DateTime loggedInAt;

  /// 服务端下发的令牌，假实现中仅作占位。
  final String? token;

  /// 序列化为可持久化的 JSON。
  JsonMap toJson() => <String, Object?>{
    'account': account,
    'method': method.name,
    'loggedInAt': loggedInAt.toIso8601String(),
    if (token != null) 'token': token,
  };

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
