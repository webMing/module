import 'package:core_config/core_config.dart';
import 'package:core_logger/core_logger.dart';
import 'package:dio/dio.dart';

import 'api_client.dart';
import 'auth_token_provider.dart';
import 'interceptors.dart';

/// 按 [AppConfig] 装配 Dio。
///
/// [adapter] 用于测试注入假适配器；生产环境留空走默认 IO 适配器。
abstract final class NetworkFactory {
  /// 创建配置好 baseUrl、超时与拦截器的 [Dio]。
  static Dio createDio({
    required AppConfig config,
    AppLogger? logger,
    AuthTokenProvider? tokenProvider,
    HttpClientAdapter? adapter,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: config.connectTimeout,
        sendTimeout: config.sendTimeout,
        receiveTimeout: config.receiveTimeout,
        responseType: ResponseType.json,
        headers: const <String, Object?>{'accept': 'application/json'},
      ),
    );

    if (adapter != null) {
      dio.httpClientAdapter = adapter;
    }
    if (tokenProvider != null) {
      dio.interceptors.add(AuthHeaderInterceptor(tokenProvider));
    }
    if (config.enableLogging && logger != null) {
      dio.interceptors.add(RequestLogInterceptor(logger: logger.child('http')));
    }
    return dio;
  }

  /// 便捷方法：一步拿到可直接使用的 [ApiClient]。
  static ApiClient createClient({
    required AppConfig config,
    AppLogger? logger,
    AuthTokenProvider? tokenProvider,
    HttpClientAdapter? adapter,
  }) => ApiClient(
    dio: createDio(
      config: config,
      logger: logger,
      tokenProvider: tokenProvider,
      adapter: adapter,
    ),
    logger: logger?.child('api'),
  );
}
