import 'package:flutter/cupertino.dart';
import 'package:ui_kit/ui_kit.dart';

/// 演示环境提示条：品牌色浅底 + 细描边，仅在提供文案或拿到验证码明文时展示。
class DemoHint extends StatelessWidget {
  /// 创建提示条。
  const DemoHint({this.text, this.debugSmsCode, super.key});

  /// 固定提示文案。
  final String? text;

  /// 验证码明文（仅假实现会返回）。
  final String? debugSmsCode;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      ?text,
      if (debugSmsCode != null) '本次短信验证码：$debugSmsCode（演示）',
    ]..removeWhere((line) => line.isEmpty);
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final primary = AppColors.primaryOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: ShapeDecoration(
        color: primary.withValues(alpha: 0.07),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: primary.withValues(alpha: 0.16)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(CupertinoIcons.info_circle_fill, size: 15, color: primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final line in lines)
                  Text(
                    line,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary(context),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
