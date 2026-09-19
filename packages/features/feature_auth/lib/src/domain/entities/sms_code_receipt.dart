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
