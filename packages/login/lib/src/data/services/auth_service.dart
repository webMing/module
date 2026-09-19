import '../../domain/models/auth_session.dart';

/// 发送短信验证码的结果。
///
/// [debugCode] 仅在本地假实现（或联调环境）中返回验证码原文，
/// 真实服务端应为 `null`。
class SmsCodeReceipt {
  /// 创建发送结果。
  const SmsCodeReceipt({this.debugCode});

  /// 便于联调查看的验证码原文。
  final String? debugCode;
}

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

/// 认证服务接口：屏蔽具体后端实现（HTTP / 本地假实现）。
abstract interface class AuthService {
  /// 使用账号 + 密码登录。
  ///
  /// 账号不存在或密码错误时抛出 [AuthException]。
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
