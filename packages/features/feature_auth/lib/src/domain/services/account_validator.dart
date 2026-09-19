/// 账号的三种形态。
enum AccountKind {
  /// 中国大陆手机号，11 位、以 1 开头。
  phone,

  /// 邮箱地址。
  email,

  /// 昵称，长度不超过 [AccountValidator.maxNicknameLength] 个字符。
  nickname,
}

/// 登录账号（手机号 / 邮箱 / 昵称）的校验规则。
///
/// 判定顺序：
/// 1. 含 `@` 视为邮箱；
/// 2. 纯数字视为手机号；
/// 3. 其余视为昵称。
abstract final class AccountValidator {
  /// 昵称允许的最大字符数（按 Unicode 码点计，中文算 1 个字符）。
  static const int maxNicknameLength = 30;

  /// 中国大陆手机号：`1` + `3-9` + 9 位数字。
  static final RegExp phoneRegExp = RegExp(r'^1[3-9]\d{9}$');

  /// 邮箱：`local@domain.tld`，且 tld 至少 2 个字母。
  static final RegExp emailRegExp = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\.[A-Za-z]{2,}$',
  );

  static final RegExp _digitsOnlyRegExp = RegExp(r'^\d+$');

  /// 识别账号形态，无法识别（空串）时返回 `null`。
  static AccountKind? detectKind(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.contains('@')) {
      return AccountKind.email;
    }
    if (_digitsOnlyRegExp.hasMatch(value)) {
      return AccountKind.phone;
    }
    return AccountKind.nickname;
  }

  /// 校验账号，合法时返回 `null`，否则返回可直接展示的错误文案。
  static String? validate(String? input) {
    final value = (input ?? '').trim();
    final kind = detectKind(value);
    if (kind == null) {
      return '请输入账号';
    }
    switch (kind) {
      case AccountKind.email:
        return emailRegExp.hasMatch(value) ? null : '邮箱格式不正确';
      case AccountKind.phone:
        return phoneRegExp.hasMatch(value) ? null : '手机号格式不正确';
      case AccountKind.nickname:
        if (value.runes.length > maxNicknameLength) {
          return '昵称长度不能超过 $maxNicknameLength 个字符';
        }
        return null;
    }
  }
}
