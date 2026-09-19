import 'package:flutter/cupertino.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 图标徽章：默认品牌渐变底 + 白色图标；传入 [tint] 时变为浅色底 + 彩色图标。
class AppIconBadge extends StatelessWidget {
  /// 创建图标徽章。
  const AppIconBadge({
    required this.icon,
    this.size = 68,
    this.iconSize = 32,
    this.tint,
    super.key,
  });

  /// 图标（Flutter 内置 CupertinoIcons）。
  final IconData icon;

  /// 徽章边长。
  final double size;

  /// 图标大小。
  final double iconSize;

  /// 浅色模式用的强调色。
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    final isTinted = tint != null;
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        gradient: isTinted ? null : AppColors.brandGradient(context),
        color: isTinted ? tint.withValues(alpha: 0.12) : null,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.30),
        ),
        shadows: isTinted ? null : AppShadows.brand(context),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: isTinted ? tint : CupertinoColors.white,
      ),
    );
  }
}

/// 统计卡片：图标 + 数值 + 标签，用于首页数据概览。
class AppStatCard extends StatelessWidget {
  /// 创建统计卡片。
  const AppStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
    super.key,
  });

  /// 图标。
  final IconData icon;

  /// 主数值。
  final String value;

  /// 说明标签。
  final String label;

  /// 强调色。
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.md,
      ),
      decoration: ShapeDecoration(
        color: AppColors.surface(context),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.cardBorder(context)),
        ),
        shadows: AppShadows.card(context),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: ShapeDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: Icon(icon, size: AppSizes.iconMd, color: tint),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTypography.metric.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
