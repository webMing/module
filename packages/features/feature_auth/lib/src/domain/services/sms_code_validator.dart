/// 短信验证码校验规则。
abstract final class SmsCodeValidator {
  /// 验证码位数。
  static const int length = 6;

  /// 允许的字符集合（单个字符），供输入框过滤使用。
  static final RegExp allowedCharPattern = RegExp(r'\d');

  static final RegExp _codeRegExp = RegExp(r'^\d{6}$');

  /// 校验验证码，合法时返回 `null`，否则返回错误文案。
  static String? validate(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) {
      return '请输入短信验证码';
    }
    if (!_codeRegExp.hasMatch(value)) {
      return '短信验证码为 $length 位数字';
    }
    return null;
  }
}
