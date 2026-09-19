import 'dart:async';

import 'package:signals/signals.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/account_validator.dart';
import '../../domain/services/auth_failure.dart';
import '../../domain/services/password_validator.dart';
import '../../domain/services/sms_code_validator.dart';

/// 重置密码页控制器（signals 版）。
///
/// 流程：输入账号 → 获取短信验证码 → 输入新密码 → 再次确认 → 提交。
/// 状态拆分与登录页一致：可写状态用 [signal]，派生状态用 [computed]，
/// 导航 / 弹窗等副作用留在页面回调里。
class ResetPasswordController {
  /// 创建重置密码控制器。
  ResetPasswordController(
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

  /// 账号输入值。
  final account = signal('');

  /// 验证码输入值。
  final smsCode = signal('');

  /// 新密码输入值。
  final newPassword = signal('');

  /// 确认密码输入值。
  final confirmPassword = signal('');

  /// 新密码是否密文展示。
  final obscureNewPassword = signal(true);

  /// 确认密码是否密文展示。
  final obscureConfirmPassword = signal(true);

  /// 是否正在提交。
  final isSubmitting = signal(false);

  /// 是否正在发送验证码。
  final isSendingCode = signal(false);

  /// 重发倒计时剩余秒数。
  final countdownSeconds = signal(0);

  /// 账号错误文案。
  final accountError = signal<String?>(null);

  /// 验证码错误文案。
  final smsCodeError = signal<String?>(null);

  /// 新密码错误文案。
  final newPasswordError = signal<String?>(null);

  /// 确认密码错误文案。
  final confirmPasswordError = signal<String?>(null);

  /// 表单级错误文案。
  final errorMessage = signal<String?>(null);

  /// 联调环境的验证码明文。
  final debugSmsCode = signal<String?>(null);

  // ---------------------------------------------------------------- 派生状态

  /// 当前是否允许发送验证码（未发送中且不在倒计时）。
  late final canSendCode = computed(
    () => !isSendingCode.value && countdownSeconds.value <= 0,
  );

  Timer? _timer;
  bool _disposed = false;

  // ------------------------------------------------------------------ 交互

  /// 更新账号输入。
  void updateAccount(String value) {
    account.value = value;
    accountError.value = null;
    errorMessage.value = null;
  }

  /// 更新验证码输入。
  void updateSmsCode(String value) {
    smsCode.value = value;
    smsCodeError.value = null;
    errorMessage.value = null;
  }

  /// 更新新密码输入。
  void updateNewPassword(String value) {
    newPassword.value = value;
    newPasswordError.value = null;
    confirmPasswordError.value = null;
    errorMessage.value = null;
  }

  /// 更新确认密码输入。
  void updateConfirmPassword(String value) {
    confirmPassword.value = value;
    confirmPasswordError.value = null;
    errorMessage.value = null;
  }

  /// 切换新密码显隐。
  void toggleNewPasswordVisibility() =>
      obscureNewPassword.value = !obscureNewPassword.value;

  /// 切换确认密码显隐。
  void toggleConfirmPasswordVisibility() =>
      obscureConfirmPassword.value = !obscureConfirmPassword.value;

  /// 发送短信验证码，成功返回 `true`。
  Future<bool> sendSmsCode() async {
    if (_disposed || !canSendCode.value) {
      return false;
    }
    accountError.value = AccountValidator.validate(account.value);
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

  /// 提交重置，成功返回 `true`。
  Future<bool> submit() async {
    if (_disposed || isSubmitting.value) {
      return false;
    }
    accountError.value = AccountValidator.validate(account.value);
    smsCodeError.value = SmsCodeValidator.validate(smsCode.value);
    newPasswordError.value = PasswordValidator.validateForNewPassword(
      newPassword.value,
    );
    confirmPasswordError.value = PasswordValidator.validateConfirmation(
      password: newPassword.value,
      confirmation: confirmPassword.value,
    );
    errorMessage.value = null;
    if (accountError.value != null ||
        smsCodeError.value != null ||
        newPasswordError.value != null ||
        confirmPasswordError.value != null) {
      return false;
    }

    isSubmitting.value = true;
    try {
      await _repository.resetPassword(
        account: account.value,
        smsCode: smsCode.value,
        newPassword: newPassword.value,
      );
      return true;
    } on AuthException catch (error) {
      _applyAuthError(error);
      return false;
    } catch (_) {
      _setError('重置失败，请稍后重试');
      return false;
    } finally {
      if (!_disposed) {
        isSubmitting.value = false;
      }
    }
  }

  /// 把数据源异常映射到具体的输入框，给出明确提示。
  void _applyAuthError(AuthException error) {
    if (_disposed) {
      return;
    }
    switch (error.code) {
      case AuthErrorCode.accountNotFound:
        accountError.value = error.message;
      case AuthErrorCode.smsCodeInvalid:
        smsCodeError.value = error.message;
      case AuthErrorCode.wrongPassword:
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

  /// 释放定时器；信号随 Controller 一起回收。
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
