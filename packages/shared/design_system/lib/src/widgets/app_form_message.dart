import 'package:flutter/cupertino.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 提示语义。
enum AppMessageTone {
  /// 错误 / 危险。
  danger,

  /// 成功。
  success,

  /// 一般信息。
  info,
}

/// 表单提示条：浅色底 + 同色描边与图标，比一行小字更醒目。
class AppFormMessage extends StatelessWidget {
  /// 创建提示条。
  const AppFormMessage({
    this.message,
    this.tone = AppMessageTone.danger,
    this.icon,
    super.key,
  });

  /// 提示文案，为空时不占位。
  final String? message;

  /// 语义色调。
  final AppMessageTone tone;

  /// 自定义图标。
  final IconData? icon;

  Color _color(BuildContext context) => switch (tone) {
    AppMessageTone.danger => AppColors.danger(context),
    AppMessageTone.success => AppColors.success(context),
    AppMessageTone.info => AppColors.primaryOf(context),
  };

  IconData get _icon => switch (tone) {
    AppMessageTone.danger => CupertinoIcons.exclamationmark_circle_fill,
    AppMessageTone.success => CupertinoIcons.checkmark_circle_fill,
    AppMessageTone.info => CupertinoIcons.info_circle_fill,
  };

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = _color(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.10),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          side: BorderSide(color: color.withValues(alpha: 0.24)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon ?? _icon, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.footnote.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
