import 'package:flutter/cupertino.dart';
import 'package:design_system/design_system.dart';

/// 「获取验证码」小胶囊按钮。
///
/// * 可发送：品牌色浅底 + 品牌色文字；
/// * 发送中：菊花；
/// * 倒计时：灰底灰字并禁用，显示剩余秒数。
class CountdownCodeButton extends StatelessWidget {
  /// 创建验证码按钮。
  const CountdownCodeButton({
    required this.countdownSeconds,
    required this.isSending,
    required this.onPressed,
    this.buttonKey,
    this.enabled = true,
    super.key,
  });

  /// 剩余倒计时秒数，`0` 表示可再次发送。
  final int countdownSeconds;

  /// 是否正在发送。
  final bool isSending;

  /// 点击回调。
  final VoidCallback onPressed;

  /// 作用于按钮的 key，便于测试定位。
  final Key? buttonKey;

  /// 是否允许发送。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canSend = enabled && !isSending && countdownSeconds <= 0;
    final primary = AppColors.primaryOf(context);
    final label = countdownSeconds > 0 ? '$countdownSeconds s' : '获取验证码';

    return CupertinoButton(
      key: buttonKey,
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      pressedOpacity: 0.7,
      onPressed: canSend ? onPressed : null,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: 30,
        constraints: const BoxConstraints(minWidth: 84),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: ShapeDecoration(
          color: canSend
              ? primary.withValues(alpha: 0.12)
              : AppColors.fill(context),
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: isSending
            ? CupertinoActivityIndicator(radius: 7, color: primary)
            : Text(
                label,
                style: AppTypography.footnote.copyWith(
                  color: canSend ? primary : AppColors.textTertiary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
