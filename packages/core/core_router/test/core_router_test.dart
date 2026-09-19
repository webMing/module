import 'package:core_di/core_di.dart';
import 'package:core_module/core_module.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _LoginPage extends StatelessWidget {
  const _LoginPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('login')));

  // 供 `_LoginPage.new` 作为无参构造函数使用。
  static _LoginPage create() => const _LoginPage();
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home')));
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.id, this.tab});

  final String id;
  final String? tab;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('detail:$id:${tab ?? '-'}')));
}

/// 模拟一个真实 feature：同时提供路由与协议。
class _HomeModule implements AppModule {
  const _HomeModule();

  @override
  ModuleDescriptor get descriptor =>
      const ModuleDescriptor(id: 'home', version: '1.0.0');

  @override
  void register(ModuleRegistrar registrar) {
    registrar
      ..registerPage('/login', _LoginPage.create)
      ..registerPage('/home', _HomePage.new)
      ..registerRoute(
        '/detail/:id',
        (context) => _DetailPage(
          id: context.pathParam('id')!,
          tab: context.query('tab'),
        ),
      )
      ..registerProtocol(const _HomeProtocol());
  }
}

/// `home://detail?id=7&tab=x` → `/detail/7?tab=x`，其余 → `/home`。
class _HomeProtocol implements ModuleProtocol {
  const _HomeProtocol();

  @override
  String get scheme => 'home';

  @override
  Future<ModuleResponse> handle(ModuleRequest request) async {
    if (request.target == 'detail') {
      return ModuleResponse.navigate(
        '/detail/:id',
        params: <String, String>{
          'id': request.param<String>('id') ?? '',
          if (request.param<String>('tab') != null)
            'tab': request.param<String>('tab')!,
        },
      );
    }
    return const ModuleResponse.navigate('/home');
  }
}

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

ModuleRegistry _bootedRegistry() => ModuleRegistry()
  ..register(const _HomeModule())
  ..boot(ServiceLocator());

void main() {
  group('RouteDefinition', () {
    test('实现 ModuleContribution，可被注册表收集', () {
      expect(
        RouteDefinition.page('/a', _HomePage.new),
        isA<ModuleContribution>(),
      );
    });

    test('page 构造器把无参构造函数包装成工厂', () {
      final definition = RouteDefinition.page('/home', _HomePage.new);
      final page = definition.factory(const ModuleRouteContext(path: '/home'));
      expect(page, isA<_HomePage>());
      expect(definition.name, isNull);
    });

    test('toString 带出路径', () {
      expect(
        RouteDefinition.page('/a', _HomePage.new).toString(),
        'RouteDefinition(/a)',
      );
    });
  });

  group('ModuleRouteContext', () {
    test('pathParam 与 query 读取参数', () {
      const context = ModuleRouteContext(
        path: '/detail/7',
        pathParameters: <String, String>{'id': '7'},
        queryParameters: <String, String>{'tab': 'x'},
      );
      expect(context.pathParam('id'), '7');
      expect(context.query('tab'), 'x');
      expect(context.pathParam('missing'), isNull);
      expect(context.query('missing'), isNull);
    });
  });

  group('AppRouter 装配', () {
    testWidgets('初始位置被渲染', (tester) async {
      final appRouter = AppRouter.fromRegistry(
        _bootedRegistry(),
        initialLocation: '/login',
      );
      await _pump(tester, appRouter.router);

      expect(find.text('login'), findsOneWidget);
      appRouter.dispose();
    });

    testWidgets('/ 重定向到初始位置', (tester) async {
      final appRouter = AppRouter.fromRegistry(
        _bootedRegistry(),
        initialLocation: '/home',
      );
      await _pump(tester, appRouter.router);

      appRouter.router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      appRouter.dispose();
    });

    testWidgets('未知路由交给 errorBuilder', (tester) async {
      final appRouter = AppRouter.fromRegistry(
        _bootedRegistry(),
        initialLocation: '/home',
        errorBuilder: (context, state) =>
            const Scaffold(body: Center(child: Text('not-found'))),
      );
      await _pump(tester, appRouter.router);

      appRouter.router.go('/nope');
      await tester.pumpAndSettle();
      expect(find.text('not-found'), findsOneWidget);
      appRouter.dispose();
    });

    test('路径重复注册时抛错', () {
      expect(
        () => AppRouter.fromRoutes(
          routes: <RouteDefinition>[
            RouteDefinition.page('/a', _HomePage.new),
            RouteDefinition.page('/a', _HomePage.new),
          ],
          initialLocation: '/a',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('路由路径重复注册：/a'),
          ),
        ),
      );
    });

    test('/ 被应用保留，模块注册时报错', () {
      expect(
        () => AppRouter.fromRoutes(
          routes: <RouteDefinition>[RouteDefinition.page('/', _HomePage.new)],
          initialLocation: '/a',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('fromRegistry 从模块贡献收集路由', () {
      final appRouter = AppRouter.fromRegistry(
        _bootedRegistry(),
        initialLocation: '/home',
      );
      final paths = appRouter.router.configuration.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toList();

      expect(
        paths,
        containsAll(<String>['/', '/login', '/home', '/detail/:id']),
      );
      appRouter.dispose();
    });
  });

  group('导航', () {
    testWidgets('go 切换页面', (tester) async {
      final appRouter = AppRouter.fromRegistry(
        _bootedRegistry(),
        initialLocation: '/login',
      );
      await _pump(tester, appRouter.router);

      await appRouter.go('/home');
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      appRouter.dispose();
    });

    testWidgets('push 之后可以 pop 回上一页', (tester) async {
      final appRouter = AppRouter.fromRegistry(
        _bootedRegistry(),
        initialLocation: '/home',
      );
      await _pump(tester, appRouter.router);

      expect(appRouter.canPop(), isFalse);
      await appRouter.push('/detail/7');
      await tester.pumpAndSettle();
      expect(find.text('detail:7:-'), findsOneWidget);
      expect(appRouter.canPop(), isTrue);

      appRouter.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      appRouter.dispose();
    });

    testWidgets('无可返回页面时 pop 不抛异常', (tester) async {
      final appRouter = AppRouter.fromRegistry(
        _bootedRegistry(),
        initialLocation: '/home',
      );
      await _pump(tester, appRouter.router);

      expect(appRouter.pop, returnsNormally);
      appRouter.dispose();
    });
  });

  group('与 ModuleBus 集成', () {
    testWidgets('协议地址经 ModuleBus 落地为真实跳转', (tester) async {
      final registry = _bootedRegistry();
      final appRouter = AppRouter.fromRegistry(
        registry,
        initialLocation: '/login',
      );
      final bus = ModuleBus(registry: registry, navigator: appRouter);

      await _pump(tester, appRouter.router);
      expect(find.text('login'), findsOneWidget);

      // 无目标参数的协议 → /home
      final home = await bus.open('home://root');
      expect(home, isA<NavigationResponse>());
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      // 带路径参数与 query 的协议 → /detail/7?tab=x
      final detail = await bus.open('home://detail?id=7&tab=x');
      expect((detail as NavigationResponse).location, '/detail/7?tab=x');
      await tester.pumpAndSettle();
      expect(find.text('detail:7:x'), findsOneWidget);

      appRouter.dispose();
    });

    testWidgets('未知 scheme 返回失败响应且不跳转', (tester) async {
      final registry = _bootedRegistry();
      final appRouter = AppRouter.fromRegistry(
        registry,
        initialLocation: '/home',
      );
      final bus = ModuleBus(registry: registry, navigator: appRouter);

      await _pump(tester, appRouter.router);
      final response = await bus.open('order://detail?id=1');

      expect(
        (response as FailureResponse).error.code,
        'module.protocol_not_found',
      );
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      appRouter.dispose();
    });

    test('AppRouter 同时实现 AppNavigator 与 ModuleNavigator', () {
      final appRouter = AppRouter.fromRegistry(
        _bootedRegistry(),
        initialLocation: '/home',
      );
      expect(appRouter, isA<AppNavigator>());
      expect(appRouter, isA<ModuleNavigator>());
      appRouter.dispose();
    });
  });

  group('注册扩展', () {
    test('registerPage / registerRoute 把路由贡献给注册表', () {
      final registry = _bootedRegistry();
      final routes = registry
          .contributionsOf<RouteDefinition>()
          .map((definition) => definition.path)
          .toList();

      expect(routes, <String>['/login', '/home', '/detail/:id']);
    });

    test('name 被透传到路由定义', () {
      var captured = 0;
      final module = _NamedRouteModule(() => captured++);
      final registry = ModuleRegistry()
        ..register(module)
        ..boot(ServiceLocator());

      final definition = registry.contributionsOf<RouteDefinition>().single;
      expect(definition.name, 'home-named');
      expect(definition.path, '/named');
      expect(captured, 0, reason: '注册阶段不应构造页面');
    });
  });
}

class _NamedRouteModule implements AppModule {
  const _NamedRouteModule(this.onBuild);

  final void Function() onBuild;

  @override
  ModuleDescriptor get descriptor =>
      const ModuleDescriptor(id: 'named', version: '1.0.0');

  @override
  void register(ModuleRegistrar registrar) =>
      registrar.registerRoute('/named', (context) {
        onBuild();
        return const _HomePage();
      }, name: 'home-named');
}
