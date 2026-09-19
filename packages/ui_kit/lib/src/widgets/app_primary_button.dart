import 'package:flutter/cupertino.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 主操作按钮：品牌渐变 + 连续圆角 + 品牌发光，加载中显示菊花并禁用。
class AppPrimaryButton extends StatelessWidget {
  /// 创建主按钮。
  const AppPrimaryButton({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.buttonKey,
    super.key,
  });

  /// 按钮文案。
  final String label;

  /// 点击回调，为空时进入禁用态。
  final VoidCallback? onPressed;

  /// 是否加载中。
  final bool isLoading;

  /// 文案左侧的可选图标。
  final IconData? icon;

  /// 作用于按钮的 key，便于测试定位。
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;
    final foreground = enabled
        ? CupertinoColors.white
        : AppColors.textTertiary(context);

    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        key: buttonKey,
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        pressedOpacity: 0.88,
        onPressed: enabled ? onPressed : null,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: double.infinity,
          height: AppSizes.control,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            gradient: enabled ? AppColors.brandGradient(context) : null,
            color: enabled ? null : AppColors.fill(context),
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            shadows: enabled ? AppShadows.brand(context) : null,
          ),
          child: isLoading
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Icon(icon, size: AppSizes.iconMd, color: foreground),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      label,
                      style: AppTypography.button.copyWith(color: foreground),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
