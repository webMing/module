/// 密码校验规则。
///
/// 密码只允许「拼音（字母）+ 数字」的组合，且长度不超过
/// [PasswordValidator.maxLength] 位；用于设置/重置密码时，还要求
/// 长度不少于 [PasswordValidator.minLength] 位并同时包含字母和数字。
abstract final class PasswordValidator {
  /// 设置密码时的最小长度。
  static const int minLength = 6;

  /// 密码允许的最大长度。
  static const int maxLength = 30;

  /// 允许的字符集合（单个字符），供输入框过滤使用。
  static final RegExp allowedCharPattern = RegExp('[A-Za-z0-9]');

  static final RegExp _allowedCharsRegExp = RegExp(r'^[A-Za-z0-9]+$');
  static final RegExp _letterRegExp = RegExp('[A-Za-z]');
  static final RegExp _digitRegExp = RegExp(r'\d');

  /// 登录时的密码校验：非空、仅字母数字、长度不超过 30。
  ///
  /// 登录不校验最小长度与组合，交由服务端判定历史密码是否有效。
  static String? validateForLogin(String? input) {
    final value = input ?? '';
    if (value.isEmpty) {
      return '请输入密码';
    }
    if (value.length > maxLength) {
      return '密码长度不能超过 $maxLength 位';
    }
    if (!_allowedCharsRegExp.hasMatch(value)) {
      return '密码只能包含字母和数字';
    }
    return null;
  }

  /// 设置 / 重置密码时的校验：6-30 位，仅字母数字，且两者都要有。
  static String? validateForNewPassword(String? input) {
    final value = input ?? '';
    if (value.isEmpty) {
      return '请输入新密码';
    }
    if (value.length < minLength || value.length > maxLength) {
      return '密码长度需为 $minLength-$maxLength 位';
    }
    if (!_allowedCharsRegExp.hasMatch(value)) {
      return '密码只能包含字母和数字';
    }
    if (!_letterRegExp.hasMatch(value) || !_digitRegExp.hasMatch(value)) {
      return '密码必须同时包含字母和数字';
    }
    return null;
  }

  /// 校验「再次确认密码」与新密码是否一致。
  static String? validateConfirmation({
    required String? password,
    required String? confirmation,
  }) {
    final value = confirmation ?? '';
    if (value.isEmpty) {
      return '请再次输入密码';
    }
    if (password != confirmation) {
      return '两次输入的密码不一致';
    }
    return null;
  }
}
