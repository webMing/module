import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// 页面背景：分组底色或品牌渐变 + 两处品牌色光晕，替代纯白平铺。
class AppPageBackground extends StatelessWidget {
  /// 创建背景。
  const AppPageBackground({
    required this.child,
    this.grouped = false,
    super.key,
  });

  /// 页面内容。
  final Widget child;

  /// 为 `true` 时使用 iOS 分组页底色（子页面用），否则使用品牌渐变（入口页用）。
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: grouped ? AppColors.groupedSurface(context) : null,
        gradient: grouped ? null : AppColors.pageGradient(context),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -150,
            right: -110,
            child: _Glow(color: AppColors.primaryOf(context), size: 320),
          ),
          Positioned(
            top: 150,
            left: -140,
            child: _Glow(color: AppColors.accent(context), size: 260),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: isDark ? 0.22 : 0.16),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// 表单页布局：内容垂直居中、超宽屏限制最大宽度、内容过高时可滚动。
class AppFormLayout extends StatelessWidget {
  /// 创建表单布局。
  const AppFormLayout({
    required this.children,
    this.scrollKey,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.xxl,
      vertical: AppSpacing.xxxl,
    ),
    this.maxWidth = AppSizes.formMaxWidth,
    super.key,
  });

  /// 纵向排列的内容。
  final List<Widget> children;

  /// 滚动容器的 key（便于测试滚动）。
  final Key? scrollKey;

  /// 页面内边距。
  final EdgeInsetsGeometry padding;

  /// 最大内容宽度。
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = math.max(
          0.0,
          constraints.maxHeight - padding.vertical,
        );
        return SingleChildScrollView(
          key: scrollKey,
          padding: padding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
