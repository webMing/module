import 'dart:async';

import 'package:signals/signals.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../domain/models/auth_session.dart';
import '../../../../domain/validators/account_validator.dart';
import '../../../../domain/validators/password_validator.dart';
import '../../../../domain/validators/sms_code_validator.dart';

/// 登录方式（与 [LoginMethod] 对应，用于 UI 切换）。
enum LoginMode {
  /// 账号 + 密码。
  password,

  /// 账号 + 短信验证码。
  smsCode,
}

/// 登录页 ViewModel（signals 版）。
///
/// 状态拆分原则：
/// * 可写状态一律用 [signal] 承载，字段本身就是订阅入口，页面用 `SignalBuilder`
///   只订阅自己需要的那几个信号，做到字段级重建；
/// * 派生状态用 [computed]，不再重复存一份（如「是否密码模式」「能否发送验证码」）；
/// * 导航这类副作用留在页面的事件回调里，不放进 `effect`，避免响应式图里做跳转。
///
/// 生命周期：信号本身不持有外部资源，随页面一起被回收；`SignalBuilder` 在卸载时
/// 会自动退订，因此这里只负责取消 [Timer]。
class LoginViewModel {
  /// 创建登录 ViewModel。
  LoginViewModel(
    this._repository, {
    this.resendSeconds = 60,
    this.tick = const Duration(seconds: 1),
  });

  final AuthRepository _repository;

  /// 倒计时刷新间隔（测试可注入更短的值）。
  final Duration tick;

  /// 重发验证码的倒计时秒数。
  final int resendSeconds;

  // ---------------------------------------------------------------- 可写状态

  /// 当前登录方式，默认密码登录。
  final mode = signal(LoginMode.password);

  /// 账号输入值。
  final account = signal('');

  /// 密码输入值。
  final password = signal('');

  /// 验证码输入值。
  final smsCode = signal('');

  /// 密码是否密文展示。
  final obscurePassword = signal(true);

  /// 是否正在提交登录。
  final isSubmitting = signal(false);

  /// 是否正在发送验证码。
  final isSendingCode = signal(false);

  /// 重发倒计时剩余秒数。
  final countdownSeconds = signal(0);

  /// 账号错误文案。
  final accountError = signal<String?>(null);

  /// 密码错误文案。
  final passwordError = signal<String?>(null);

  /// 验证码错误文案。
  final smsCodeError = signal<String?>(null);

  /// 表单级错误文案（服务端返回或网络异常）。
  final errorMessage = signal<String?>(null);

  /// 联调环境的验证码明文，生产环境为 `null`。
  final debugSmsCode = signal<String?>(null);

  // ---------------------------------------------------------------- 派生状态

  /// 是否处于密码登录模式。
  late final isPasswordMode = computed(() => mode.value == LoginMode.password);

  /// 当前是否允许发送验证码（未发送中且不在倒计时）。
  late final canSendCode = computed(
    () => !isSendingCode.value && countdownSeconds.value <= 0,
  );

  Timer? _timer;
  bool _disposed = false;

  // ------------------------------------------------------------------ 交互

  /// 切换密码 / 验证码登录。
  void switchMode(LoginMode value) {
    if (mode.value == value) {
      return;
    }
    mode.value = value;
    passwordError.value = null;
    smsCodeError.value = null;
    errorMessage.value = null;
  }

  /// 更新账号输入。
  void updateAccount(String value) {
    account.value = value;
    accountError.value = null;
    errorMessage.value = null;
  }

  /// 更新密码输入。
  void updatePassword(String value) {
    password.value = value;
    passwordError.value = null;
    errorMessage.value = null;
  }

  /// 更新验证码输入。
  void updateSmsCode(String value) {
    smsCode.value = value;
    smsCodeError.value = null;
    errorMessage.value = null;
  }

  /// 切换密码显隐。
  void togglePasswordVisibility() =>
      obscurePassword.value = !obscurePassword.value;

  /// 发送短信验证码，成功返回 `true`。
  Future<bool> sendSmsCode() async {
    if (_disposed || !canSendCode.value) {
      return false;
    }
    accountError.value = AccountValidator.validate(account.value);
    smsCodeError.value = null;
    errorMessage.value = null;
    if (accountError.value != null) {
      return false;
    }

    isSendingCode.value = true;
    try {
      final receipt = await _repository.sendSmsCode(account: account.value);
      if (_disposed) {
        return false;
      }
      debugSmsCode.value = receipt.debugCode;
      _startCountdown();
      return true;
    } on AuthException catch (error) {
      _applyAuthError(error);
      return false;
    } catch (_) {
      _setError('验证码发送失败，请稍后重试');
      return false;
    } finally {
      if (!_disposed) {
        isSendingCode.value = false;
      }
    }
  }

  /// 提交登录，成功返回会话，失败返回 `null` 并写入错误文案。
  Future<AuthSession?> submit() async {
    if (_disposed || isSubmitting.value) {
      return null;
    }
    accountError.value = AccountValidator.validate(account.value);
    passwordError.value = isPasswordMode.value
        ? PasswordValidator.validateForLogin(password.value)
        : null;
    smsCodeError.value = isPasswordMode.value
        ? null
        : SmsCodeValidator.validate(smsCode.value);
    errorMessage.value = null;
    if (accountError.value != null ||
        passwordError.value != null ||
        smsCodeError.value != null) {
      return null;
    }

    isSubmitting.value = true;
    try {
      return isPasswordMode.value
          ? await _repository.loginWithPassword(
              account: account.value,
              password: password.value,
            )
          : await _repository.loginWithSmsCode(
              account: account.value,
              smsCode: smsCode.value,
            );
    } on AuthException catch (error) {
      _applyAuthError(error);
      return null;
    } catch (_) {
      _setError('登录失败，请稍后重试');
      return null;
    } finally {
      if (!_disposed) {
        isSubmitting.value = false;
      }
    }
  }

  /// 把数据源异常映射到具体的输入框，给出明确提示。
  ///
  /// * 账号不存在 → 账号输入框；
  /// * 密码错误 → 密码输入框；
  /// * 验证码错误 / 失效 → 验证码输入框；
  /// * 其余（网络等）→ 表单级横幅。
  void _applyAuthError(AuthException error) {
    if (_disposed) {
      return;
    }
    switch (error.code) {
      case AuthErrorCode.accountNotFound:
        accountError.value = error.message;
      case AuthErrorCode.wrongPassword:
        passwordError.value = error.message;
      case AuthErrorCode.smsCodeInvalid:
        smsCodeError.value = error.message;
      case AuthErrorCode.invalidCredentials:
      case AuthErrorCode.smsCodeSendFailed:
      case AuthErrorCode.unknown:
        _setError(error.message);
    }
  }

  void _setError(String message) {
    if (!_disposed) {
      errorMessage.value = message;
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    countdownSeconds.value = resendSeconds;
    _timer = Timer.periodic(tick, (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      final next = countdownSeconds.value - 1;
      countdownSeconds.value = next < 0 ? 0 : next;
      if (countdownSeconds.value <= 0) {
        timer.cancel();
        _timer = null;
      }
    });
  }

  /// 释放定时器；信号随 ViewModel 一起回收。
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
