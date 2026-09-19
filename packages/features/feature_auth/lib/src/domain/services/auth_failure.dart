/// 认证失败的具体原因，UI 可据此把提示放到对应输入框。
enum AuthErrorCode {
  /// 账号不存在（未注册 / 输错）。
  accountNotFound,

  /// 账号存在但密码错误。
  wrongPassword,

  /// 账号或密码错误（后端不区分两者时的兜底）。
  invalidCredentials,

  /// 短信验证码错误或已失效。
  smsCodeInvalid,

  /// 验证码发送失败。
  smsCodeSendFailed,

  /// 其他未归类错误（网络异常等）。
  unknown,
}

/// 认证相关的业务异常，[message] 可直接展示给用户。
class AuthException implements Exception {
  /// 创建认证异常。
  const AuthException(this.message, {this.code = AuthErrorCode.unknown});

  /// 面向用户的错误文案。
  final String message;

  /// 错误原因，便于 UI 精确定位到具体输入框。
  final AuthErrorCode code;

  @override
  String toString() => 'AuthException($code): $message';
}
