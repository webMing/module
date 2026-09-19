import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/home.dart';

void main() {
  testWidgets('展示账号与登录方式', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const CupertinoApp(
        home: HomePage(account: 'demo', loginMethodLabel: '密码登录'),
      ),
    );

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('你好，demo'), findsOneWidget);
    expect(find.text('已登录 · 密码登录'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('我的资料'), findsOneWidget);
  });

  testWidgets('未提供登录方式时只展示已登录', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const CupertinoApp(home: HomePage(account: '13800138000')),
    );

    expect(find.text('已登录'), findsOneWidget);
    expect(find.text('你好，13800138000'), findsOneWidget);
  });

  testWidgets('点击退出登录触发回调', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    var loggedOut = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: HomePage(account: 'demo', onLogout: () => loggedOut = true),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('home_logout_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_logout_tile')));
    await tester.pump();

    expect(loggedOut, isTrue);
  });
}
