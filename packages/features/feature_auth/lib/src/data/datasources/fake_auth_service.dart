import 'package:core_session/core_session.dart';

import '../../domain/entities/sms_code_receipt.dart';
import '../../domain/services/auth_failure.dart';
import 'auth_service.dart';

/// 可替换的本地认证实现，用于在没有后端接口时跑通完整流程。
///
/// 规则：
/// * 只有 [registeredAccounts] 中的账号存在（默认只有演示账号
///   [demoAccount]），其余账号会返回「账号不存在」；
/// * 已注册账号的默认密码为 [defaultPassword]（`abc123`），密码不匹配时
///   返回「密码错误」；
/// * 短信验证码固定为 [smsCode]（`123456`），且必须先调用
///   [sendSmsCode] 才算生效；
/// * [resetPassword] 成功后该账号的密码会被真正改写。
///
/// 后续接入真实后端时，只需新增一个 `AuthService` 实现并替换注册即可。
class FakeAuthService implements AuthService {
  /// 创建假实现。
  ///
  /// [latency] 用于模拟网络耗时（测试可传 [Duration.zero]）；
  /// [registeredAccounts] 用于自定义「已注册账号」集合。
  FakeAuthService({
    this.latency = const Duration(milliseconds: 400),
    Set<String>? registeredAccounts,
  }) : _registeredAccounts = <String>{
         ...registeredAccounts ?? const <String>{demoAccount},
       };

  /// 模拟的网络耗时。
  final Duration latency;

  /// 演示账号。
  static const String demoAccount = 'demo';

  /// 演示用的默认密码。
  static const String defaultPassword = 'abc123';

  /// 演示用的短信验证码。
  static const String smsCode = '123456';

  final Map<String, String> _passwords = <String, String>{};
  final Map<String, String> _issuedCodes = <String, String>{};
  final Set<String> _registeredAccounts;

  Future<void> _simulateLatency() {
    if (latency == Duration.zero) {
      return Future<void>.value();
    }
    return Future<void>.delayed(latency);
  }

  bool _isRegistered(String account) => _registeredAccounts.contains(account);

  String _passwordOf(String account) => _passwords[account] ?? defaultPassword;

  bool _isCodeValid(String account, String code) =>
      _issuedCodes[account] == code;

  /// 账号不存在时统一抛出该异常，方便 UI 高亮账号输入框。
  Never _throwAccountNotFound() => throw const AuthException(
    '账号不存在，请检查账号是否正确',
    code: AuthErrorCode.accountNotFound,
  );

  @override
  Future<AuthSession> loginWithPassword({
    required String account,
    required String password,
  }) async {
    await _simulateLatency();
    final normalized = account.trim();
    if (!_isRegistered(normalized)) {
      _throwAccountNotFound();
    }
    if (password != _passwordOf(normalized)) {
      throw const AuthException(
        '密码错误，请重新输入',
        code: AuthErrorCode.wrongPassword,
      );
    }
    return AuthSession(
      account: normalized,
      method: LoginMethod.password,
      loggedInAt: DateTime.now(),
      token: 'fake-password-token',
    );
  }

  @override
  Future<AuthSession> loginWithSmsCode({
    required String account,
    required String smsCode,
  }) async {
    await _simulateLatency();
    final normalized = account.trim();
    if (!_isRegistered(normalized)) {
      _throwAccountNotFound();
    }
    if (!_isCodeValid(normalized, smsCode)) {
      throw const AuthException(
        '验证码错误或已失效，请重新获取',
        code: AuthErrorCode.smsCodeInvalid,
      );
    }
    return AuthSession(
      account: normalized,
      method: LoginMethod.smsCode,
      loggedInAt: DateTime.now(),
      token: 'fake-sms-token',
    );
  }

  @override
  Future<SmsCodeReceipt> sendSmsCode({required String account}) async {
    await _simulateLatency();
    final normalized = account.trim();
    if (!_isRegistered(normalized)) {
      _throwAccountNotFound();
    }
    _issuedCodes[normalized] = smsCode;
    return const SmsCodeReceipt(debugCode: smsCode);
  }

  @override
  Future<void> resetPassword({
    required String account,
    required String smsCode,
    required String newPassword,
  }) async {
    await _simulateLatency();
    final normalized = account.trim();
    if (!_isRegistered(normalized)) {
      _throwAccountNotFound();
    }
    if (!_isCodeValid(normalized, smsCode)) {
      throw const AuthException(
        '验证码错误或已失效，请重新获取',
        code: AuthErrorCode.smsCodeInvalid,
      );
    }
    _passwords[normalized] = newPassword;
    _issuedCodes.remove(normalized);
  }
}
