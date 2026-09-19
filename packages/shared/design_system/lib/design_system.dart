/// 共享设计系统：颜色、间距、字体、阴影令牌与通用 iOS 风格组件。
///
/// 设计原则：
/// * 所有颜色都通过 `resolveFrom(context)` 解析，自动适配浅色 / 深色；
/// * 间距、圆角、字号全部走令牌，避免各页面各写一套魔法数字；
/// * 圆角使用 iOS 的连续圆角（squircle）以获得更柔和的观感。
library;

export 'src/tokens/app_colors.dart';
export 'src/tokens/app_spacing.dart';
export 'src/tokens/app_typography.dart';
export 'src/widgets/app_card.dart';
export 'src/widgets/app_form_message.dart';
export 'src/widgets/app_icon_badge.dart';
export 'src/widgets/app_page_background.dart';
export 'src/widgets/app_primary_button.dart';
export 'src/widgets/app_segmented_control.dart';
export 'src/widgets/app_text_field.dart';
