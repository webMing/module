import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

Widget _host(Widget child) => CupertinoApp(home: child);

void main() {
  testWidgets('AppPrimaryButton 点击回调与加载态', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Center(
          child: AppPrimaryButton(label: '登 录', onPressed: () => taps++),
        ),
      ),
    );

    await tester.tap(find.text('登 录'));
    await tester.pump();
    expect(taps, 1);

    await tester.pumpWidget(
      _host(
        const Center(child: AppPrimaryButton(label: '登 录', isLoading: true)),
      ),
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('登 录'), findsNothing);
  });

  testWidgets('AppSegmentedControl 切换回调与选中态', (tester) async {
    var value = 'a';
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => Center(
            child: SizedBox(
              width: 300,
              child: AppSegmentedControl<String>(
                segments: const <String, String>{'a': '密码登录', 'b': '验证码登录'},
                groupValue: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('密码登录'), findsOneWidget);
    await tester.tap(find.text('验证码登录'));
    await tester.pumpAndSettle();
    expect(value, 'b');
  });

  testWidgets('AppTextField 聚焦态与错误提示', (tester) async {
    await tester.pumpWidget(
      _host(
        Center(
          child: SizedBox(
            width: 320,
            child: AppTextField(
              icon: CupertinoIcons.person,
              placeholder: '请输入账号',
              errorText: '账号不存在',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('账号不存在'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.person), findsOneWidget);
  });

  test('设计令牌成体系', () {
    expect(AppSpacing.lg, greaterThan(AppSpacing.md));
    expect(AppRadius.xl, greaterThan(AppRadius.md));
    // 输入框比主按钮矮，符合 iOS 单行输入框 44pt 规范。
    expect(AppSizes.field, 44);
    expect(AppSizes.control, 52);
    expect(AppSizes.field, lessThan(AppSizes.control));
    expect(AppTypography.button.fontWeight, FontWeight.w600);
    expect(
      AppTypography.largeTitle.fontSize,
      greaterThan(AppTypography.body.fontSize!),
    );
  });
}
