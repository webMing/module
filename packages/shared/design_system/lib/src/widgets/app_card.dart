import 'package:flutter/cupertino.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// 卡片：iOS 连续圆角 + 轻阴影 + 极细描边，用于承载表单与内容区块。
class AppCard extends StatelessWidget {
  /// 创建卡片。
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.margin,
    super.key,
  });

  /// 卡片内容。
  final Widget child;

  /// 内边距。
  final EdgeInsetsGeometry padding;

  /// 外边距。
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: ShapeDecoration(
        color: AppColors.surface(context),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.cardBorder(context)),
        ),
        shadows: AppShadows.card(context),
      ),
      child: child,
    );
  }
}
