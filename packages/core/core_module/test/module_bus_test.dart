import 'package:core_di/core_di.dart';
import 'package:core_error/core_error.dart';
import 'package:core_module/core_module.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录收到的请求并返回预设响应的协议。
class _StubProtocol implements ModuleProtocol {
  _StubProtocol({
    this.scheme = 'product',
    this.response = const ModuleResponse.done(),
    this.error,
  });

  @override
  final String scheme;

  final ModuleResponse response;
  final Object? error;
  ModuleRequest? lastRequest;

  @override
  Future<ModuleResponse> handle(ModuleRequest request) async {
    lastRequest = request;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return response;
  }
}

class _RecordingNavigator implements ModuleNavigator {
  _RecordingNavigator({this.error});

  final Object? error;
  final List<String> opened = <String>[];

  @override
  Future<void> open(String location) async {
    opened.add(location);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
  }
}

/// 只注册一个协议的辅助模块。
class _ProtocolModule implements AppModule {
  _ProtocolModule(this.protocol);

  final ModuleProtocol protocol;

  @override
  ModuleDescriptor get descriptor =>
      ModuleDescriptor(id: protocol.scheme, version: '1.0.0');

  @override
  void register(ModuleRegistrar registrar) =>
      registrar.registerProtocol(protocol);
}

ModuleBus _busWith(ModuleProtocol protocol, {ModuleNavigator? navigator}) {
  final registry = ModuleRegistry()
    ..register(_ProtocolModule(protocol))
    ..boot(ServiceLocator());
  return ModuleBus(registry: registry, navigator: navigator);
}

void main() {
  group('open 成功路径', () {
    test('返回协议给出的响应', () async {
      final bus = _busWith(
        _StubProtocol(response: const ModuleResponse.done()),
      );
      final response = await bus.open('product://detail');
      expect(response, isA<DoneResponse>());
    });

    test('不带导航端口时，非跳转响应不需要导航', () async {
      final bus = _busWith(
        _StubProtocol(response: const ModuleResponse.value(42)),
      );
      final response = await bus.open('product://detail');
      expect((response as ValueResponse).value, 42);
    });

    test('跳转响应通过导航端口落地', () async {
      final navigator = _RecordingNavigator();
      final bus = _busWith(
        _StubProtocol(
          response: const ModuleResponse.navigate(
            '/product/detail/:id',
            params: <String, String>{'id': '10001', 'from': 'home'},
          ),
        ),
        navigator: navigator,
      );

      final response = await bus.open('product://detail?id=10001');
      expect(response, isA<NavigationResponse>());
      expect(navigator.opened, <String>['/product/detail/10001?from=home']);
    });
  });

  group('请求解析', () {
    test('scheme 与 target 来自协议地址', () async {
      final protocol = _StubProtocol();
      final bus = _busWith(protocol);

      await bus.open('product://detail?id=10001');
      expect(protocol.lastRequest?.scheme, 'product');
      expect(protocol.lastRequest?.target, 'detail');
    });

    test('query 与显式 params 合并，显式参数优先', () async {
      final protocol = _StubProtocol();
      final bus = _busWith(protocol);

      await bus.open(
        'product://detail?id=1&keep=uri',
        params: <String, Object?>{'id': 2, 'extra': 'x'},
      );

      expect(protocol.lastRequest?.params['id'], 2);
      expect(protocol.lastRequest?.params['keep'], 'uri');
      expect(protocol.lastRequest?.params['extra'], 'x');
    });

    test('param<T> 类型不符时返回 null', () async {
      final protocol = _StubProtocol();
      final bus = _busWith(protocol);

      await bus.open('product://detail?id=10001');
      expect(protocol.lastRequest?.param<String>('id'), '10001');
      expect(protocol.lastRequest?.param<String>('missing'), isNull);
    });

    test('没有 scheme 的地址抛 ArgumentError', () async {
      final bus = _busWith(_StubProtocol());
      expect(() => bus.open('/login'), throwsA(isA<ArgumentError>()));
    });

    test('target 在只有 path 时退回 path', () {
      final request = ModuleRequest.parse('product:///detail');
      expect(request.target, 'detail');
    });
  });

  group('失败路径', () {
    test('未知 scheme 返回 protocol_not_found', () async {
      final bus = _busWith(_StubProtocol(scheme: 'product'));
      final response = await bus.open('unknown://x');

      expect(
        (response as FailureResponse).error.code,
        'module.protocol_not_found',
      );
      expect(response.error, isA<ModuleException>());
    });

    test('协议抛 AppException 时原样返回', () async {
      const failure = NetworkException(
        '断网',
        kind: NetworkErrorKind.noConnection,
      );
      final bus = _busWith(_StubProtocol(error: failure));

      final response = await bus.open('product://detail');
      expect((response as FailureResponse).error, same(failure));
    });

    test('协议抛普通异常时包装为 protocol_failed', () async {
      final bus = _busWith(_StubProtocol(error: StateError('boom')));
      final response = await bus.open('product://detail');

      expect(
        (response as FailureResponse).error.code,
        'module.protocol_failed',
      );
      expect(response.error.cause, isA<StateError>());
      expect(response.error.effectiveStackTrace, isNotNull);
    });

    test('未注入导航端口时跳转返回 navigator_missing', () async {
      final bus = _busWith(
        _StubProtocol(response: const ModuleResponse.navigate('/home')),
      );
      final response = await bus.open('product://detail');

      expect(
        (response as FailureResponse).error.code,
        'module.navigator_missing',
      );
      expect(response.error.message, contains('/home'));
    });

    test('导航端口抛异常时返回 navigation_failed', () async {
      final bus = _busWith(
        _StubProtocol(response: const ModuleResponse.navigate('/home')),
        navigator: _RecordingNavigator(error: StateError('no route')),
      );
      final response = await bus.open('product://detail');

      expect(
        (response as FailureResponse).error.code,
        'module.navigation_failed',
      );
    });
  });

  group('supports', () {
    test('按 scheme 判断是否有模块提供协议', () {
      final bus = _busWith(_StubProtocol(scheme: 'product'));
      expect(bus.supports('product'), isTrue);
      expect(bus.supports('order'), isFalse);
    });
  });

  group('buildLocation', () {
    test('填充路径占位符', () {
      expect(
        buildLocation('/product/:id', <String, String>{'id': '7'}),
        '/product/7',
      );
    });

    test('未消费的参数追加为 query', () {
      expect(
        buildLocation('/product/:id', <String, String>{
          'id': '7',
          'tab': 'detail',
        }),
        '/product/7?tab=detail',
      );
    });

    test('没有占位符时全部转为 query', () {
      expect(
        buildLocation('/home', <String, String>{'a': '1', 'b': '2'}),
        '/home?a=1&b=2',
      );
    });

    test('参数值会被 URL 编码', () {
      expect(
        buildLocation('/search/:q', <String, String>{'q': 'a b'}),
        '/search/a%20b',
      );
    });

    test('空参数返回原路径', () {
      expect(buildLocation('/home'), '/home');
    });
  });
}
