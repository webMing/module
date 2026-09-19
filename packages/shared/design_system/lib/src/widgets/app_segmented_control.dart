import 'package:flutter/cupertino.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// 分段控件：iOS 风格，白色滑块 + 阴影 + 滑动动画。
///
/// [segments] 为「值 → 文案」的有序映射。
class AppSegmentedControl<T> extends StatelessWidget {
  /// 创建分段控件。
  const AppSegmentedControl({
    required this.segments,
    required this.groupValue,
    required this.onChanged,
    super.key,
  });

  /// 分段集合。
  final Map<T, String> segments;

  /// 当前选中值。
  final T groupValue;

  /// 选中变化回调。
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = segments.keys.toList(growable: false);
    final rawIndex = values.indexOf(groupValue);
    final index = rawIndex < 0 ? 0 : rawIndex;
    const inset = 3.0;

    return Container(
      height: AppSizes.segmented,
      padding: const EdgeInsets.all(inset),
      decoration: ShapeDecoration(
        color: AppColors.fill(context),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / values.length;
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: AppDurations.normal,
                curve: Curves.easeOutCubic,
                left: index * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AppColors.surface(context),
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    shadows: AppShadows.thumb(context),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  for (final value in values)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(value),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: AppDurations.fast,
                            style: AppTypography.subheadline.copyWith(
                              color: value == groupValue
                                  ? AppColors.textPrimary(context)
                                  : AppColors.textSecondary(context),
                              fontWeight: value == groupValue
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            child: Text(segments[value]!),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
