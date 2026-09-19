import 'dart:convert';
import 'dart:typed_data';

import 'package:core_config/core_config.dart';
import 'package:core_error/core_error.dart';
import 'package:core_logger/core_logger.dart';
import 'package:core_network/core_network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const AppConfig _config = AppConfig(
  environment: AppEnvironment.development,
  apiBaseUrl: 'https://api.test',
);

/// 假 HTTP 适配器：完全离线，并可记录收到的请求。
final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonBody(Object? body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

DioException _dioError(
  DioExceptionType type, {
  int? status,
  String path = 'https://api.test/ping',
}) {
  final options = RequestOptions(path: path);
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response<dynamic>(requestOptions: options, statusCode: status),
    error: 'underlying',
  );
}

/// 令牌来源替身。
final class _TokenProvider implements AuthTokenProvider {
  _TokenProvider(this.token);

  @override
  String? token;
}

void main() {
  group('mapDioException', () {
    test('四类超时都归一化为 timeout', () {
      for (final type in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        final failure = mapDioException(_dioError(type));
        expect(failure.kind, NetworkErrorKind.timeout);
        expect(failure.code, 'network.timeout');
        expect(failure.isRetryable, isTrue);
        expect(failure.message, '请求超时，请稍后重试');
      }
    });

    test('连接错误与证书错误归一化为 noConnection', () {
      for (final type in <DioExceptionType>[
        DioExceptionType.connectionError,
        DioExceptionType.badCertificate,
      ]) {
        expect(
          mapDioException(_dioError(type)).kind,
          NetworkErrorKind.noConnection,
        );
      }
    });

    test('取消归一化为 cancelled 且不可重试', () {
      final failure = mapDioException(_dioError(DioExceptionType.cancel));
      expect(failure.kind, NetworkErrorKind.cancelled);
      expect(failure.isRetryable, isFalse);
    });

    test('badResponse 带出状态码，5xx 可重试', () {
      final failure = mapDioException(
        _dioError(DioExceptionType.badResponse, status: 503),
      );
      expect(failure.kind, NetworkErrorKind.badResponse);
      expect(failure.statusCode, 503);
      expect(failure.isRetryable, isTrue);
      expect(failure.message, contains('503'));
    });

    test('unknown 有状态码时按 badResponse 处理', () {
      final failure = mapDioException(
        _dioError(DioExceptionType.unknown, status: 404),
      );
      expect(failure.kind, NetworkErrorKind.badResponse);
      expect(failure.statusCode, 404);
      expect(failure.isRetryable, isFalse);
    });

    test('unknown 无状态码时为 unknown', () {
      final failure = mapDioException(_dioError(DioExceptionType.unknown));
      expect(failure.kind, NetworkErrorKind.unknown);
      expect(failure.code, 'network.unknown');
    });

    test('保留请求地址、底层原因与堆栈', () {
      final error = _dioError(
        DioExceptionType.connectionError,
        path: 'https://api.test/orders',
      );
      final failure = mapDioException(error, stackTrace: StackTrace.current);

      expect(failure.uri, Uri.parse('https://api.test/orders'));
      expect(failure.cause, 'underlying');
      expect(failure.effectiveStackTrace, isNotNull);
      expect(failure, isA<AppException>());
    });
  });

  group('ApiClient', () {
    test('getMap 返回解码后的对象', () async {
      final adapter = _FakeAdapter((_) async => _jsonBody(<String, Object?>{'id': 1}));
      final client = NetworkFactory.createClient(
        config: _config,
        adapter: adapter,
      );

      expect(await client.getMap('/ping'), <String, Object?>{'id': 1});
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.toString(), 'https://api.test/ping');
    });

    test('getList 返回数组，查询参数被透传', () async {
      final adapter = _FakeAdapter((_) async => _jsonBody(<Object?>[1, 2]));
      final client = NetworkFactory.createClient(
        config: _config,
        adapter: adapter,
      );

      expect(
        await client.getList('/items', query: <String, Object?>{'page': 2}),
        <Object?>[1, 2],
      );
      expect(adapter.requests.single.uri.queryParameters['page'], '2');
    });

    test('postMap 发送请求体', () async {
      final adapter = _FakeAdapter((_) async => _jsonBody(<String, Object?>{'ok': true}));
      final client = NetworkFactory.createClient(
        config: _config,
        adapter: adapter,
      );

      await client.postMap('/login', body: <String, Object?>{'account': 'demo'});
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(
        jsonDecode(jsonEncode(request.data)),
        <String, Object?>{'account': 'demo'},
      );
    });

    test('响应结构不符时抛 badPayload', () async {
      final adapter = _FakeAdapter((_) async => _jsonBody(<Object?>[1, 2]));
      final client = NetworkFactory.createClient(
        config: _config,
        adapter: adapter,
      );

      await expectLater(
        client.getMap('/ping'),
        throwsA(
          isA<NetworkException>()
              .having((e) => e.kind, 'kind', NetworkErrorKind.badPayload)
              .having((e) => e.code, 'code', 'network.badPayload'),
        ),
      );
    });

    test('非 2xx 抛 badResponse 并带上状态码', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonBody(<String, Object?>{'error': 'boom'}, status: 500),
      );
      final client = NetworkFactory.createClient(
        config: _config,
        adapter: adapter,
      );

      await expectLater(
        client.getMap('/ping'),
        throwsA(
          isA<NetworkException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );
    });

    test('失败时写一条 warn 日志', () async {
      final logger = MemoryLogger();
      final adapter = _FakeAdapter(
        (_) async => _jsonBody(<String, Object?>{}, status: 404),
      );
      final client = NetworkFactory.createClient(
        config: _config.copyWith(enableLogging: false),
        logger: logger,
        adapter: adapter,
      );

      await expectLater(client.getMap('/ping'), throwsA(isA<NetworkException>()));

      final record = logger.records.single;
      expect(record.level, LogLevel.warn);
      expect(record.name, 'api');
      expect(record.message, contains('/ping'));
      expect(record.context?['code'], 'network.badResponse');
    });
  });

  group('AuthHeaderInterceptor', () {
    test('有令牌时附加 Bearer 头', () async {
      final adapter = _FakeAdapter((_) async => _jsonBody(<String, Object?>{}));
      final client = NetworkFactory.createClient(
        config: _config,
        tokenProvider: _TokenProvider('token-1'),
        adapter: adapter,
      );

      await client.getMap('/me');
      expect(
        adapter.requests.single.headers['authorization'],
        'Bearer token-1',
      );
    });

    test('无令牌或空令牌时不附加头', () async {
      for (final token in <String?>[null, '']) {
        final adapter = _FakeAdapter((_) async => _jsonBody(<String, Object?>{}));
        final client = NetworkFactory.createClient(
          config: _config,
          tokenProvider: _TokenProvider(token),
          adapter: adapter,
        );

        await client.getMap('/me');
        expect(adapter.requests.single.headers.containsKey('authorization'), isFalse);
      }
    });
  });

  group('RequestLogInterceptor', () {
    test('无 config 日志开关时不加日志拦截器', () {
      final dio = NetworkFactory.createDio(
        config: _config.copyWith(enableLogging: false),
        logger: MemoryLogger(),
      );
      // dio 自身会注入 ImplyContentTypeInterceptor，所以只能按类型断言。
      expect(dio.interceptors.whereType<RequestLogInterceptor>(), isEmpty);
    });

    test('开启后记录请求与响应', () async {
      final logger = MemoryLogger();
      final adapter = _FakeAdapter((_) async => _jsonBody(<String, Object?>{}));
      final client = NetworkFactory.createClient(
        config: _config.copyWith(enableLogging: true),
        logger: logger,
        adapter: adapter,
      );

      await client.getMap('/ping');

      expect(logger.hasMessage('→ GET https://api.test/ping'), isTrue);
      expect(
        logger.records.any((r) => r.message.startsWith('← 200')),
        isTrue,
      );
    });

    test('默认不记录请求体，logBody 打开后才记录', () async {
      for (final logBody in <bool>[false, true]) {
        final logger = MemoryLogger();
        final adapter = _FakeAdapter((_) async => _jsonBody(<String, Object?>{}));
        final dio = Dio(BaseOptions(baseUrl: _config.apiBaseUrl))
          ..httpClientAdapter = adapter
          ..interceptors.add(
            RequestLogInterceptor(logger: logger, logBody: logBody),
          );

        await ApiClient(dio: dio).postMap(
          '/login',
          body: <String, Object?>{'account': 'demo'},
        );

        final requestLog = logger.records.first;
        if (logBody) {
          expect(requestLog.context?['body'], isNotNull);
        } else {
          expect(requestLog.context, isNull);
        }
      }
    });

    test('失败时记录 warn 日志', () async {
      final logger = MemoryLogger();
      final adapter = _FakeAdapter(
        (_) async => _jsonBody(<String, Object?>{}, status: 500),
      );
      final client = NetworkFactory.createClient(
        config: _config.copyWith(enableLogging: true),
        logger: logger,
        adapter: adapter,
      );

      await expectLater(client.getMap('/ping'), throwsA(isA<NetworkException>()));
      expect(logger.hasLevel(LogLevel.warn), isTrue);
    });
  });

  group('NetworkFactory', () {
    test('baseUrl 与超时来自 AppConfig', () {
      const config = AppConfig(
        environment: AppEnvironment.staging,
        apiBaseUrl: 'https://api.staging.test',
        connectTimeout: Duration(seconds: 3),
        sendTimeout: Duration(seconds: 4),
        receiveTimeout: Duration(seconds: 5),
      );
      final dio = NetworkFactory.createDio(config: config);

      expect(dio.options.baseUrl, 'https://api.staging.test');
      expect(dio.options.connectTimeout, const Duration(seconds: 3));
      expect(dio.options.sendTimeout, const Duration(seconds: 4));
      expect(dio.options.receiveTimeout, const Duration(seconds: 5));
      expect(dio.options.headers['accept'], 'application/json');
    });

    test('未提供 tokenProvider 时不加认证拦截器', () {
      final dio = NetworkFactory.createDio(
        config: _config.copyWith(enableLogging: false),
      );
      expect(dio.interceptors.whereType<AuthHeaderInterceptor>(), isEmpty);
    });

    test('createClient 的 logger 派生出 api 子来源', () async {
      final logger = MemoryLogger();
      final adapter = _FakeAdapter(
        (_) async => _jsonBody(<String, Object?>{}, status: 500),
      );
      final client = NetworkFactory.createClient(
        config: _config.copyWith(enableLogging: false),
        logger: logger,
        adapter: adapter,
      );

      await expectLater(client.getMap('/x'), throwsA(isA<NetworkException>()));
      expect(logger.records.single.name, 'api');
    });
  });
}
