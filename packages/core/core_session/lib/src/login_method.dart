/// 登录方式。
enum LoginMethod {
  /// 账号 + 密码登录。
  password(label: '密码登录'),

  /// 账号 + 短信验证码登录。
  smsCode(label: '验证码登录');

  const LoginMethod({required this.label});

  /// 面向用户的文案。
  ///
  /// 放在枚举里而不是各页面各写一份 switch，避免同一概念在不同模块里
  /// 出现不一样的措辞。
  final String label;

  /// 解析枚举名，无法识别时退回 [LoginMethod.password]。
  static LoginMethod parse(String raw) {
    final normalized = raw.trim();
    for (final value in values) {
      if (value.name == normalized) {
        return value;
      }
    }
    return password;
  }
}
