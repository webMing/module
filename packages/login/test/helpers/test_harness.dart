import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/login.dart';

/// 零延迟的假仓库，测试中可直接断言结果。
AuthRepository buildAuthRepository() =>
    AuthRepository(FakeAuthService(latency: Duration.zero));

/// 用 CupertinoApp 包裹被测页面（与线上应用保持一致的主题）。
Widget wrapWithCupertinoApp(Widget child) => CupertinoApp(
  theme: const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: CupertinoColors.systemBlue,
  ),
  home: child,
);

/// 放大逻辑画布，避免长表单在默认 800x600 下被判定为不可见。
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// 卸载页面，确保 ViewModel 里的倒计时 Timer 被取消。
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// 等待一次零延迟的异步回调完成。
Future<void> settleAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}
