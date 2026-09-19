import 'package:core_logger/core_logger.dart';
import 'package:dio/dio.dart';

import 'auth_token_provider.dart';

/// 自动附加 `Authorization: Bearer <token>` 的拦截器。
class AuthHeaderInterceptor extends Interceptor {
  /// 用令牌来源创建拦截器。
  AuthHeaderInterceptor(this._tokenProvider);

  final AuthTokenProvider _tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider.token;
    if (token != null && token.isNotEmpty) {
      options.headers['authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// 把请求 / 响应 / 失败写进 [AppLogger] 的拦截器。
///
/// 只做日志，不做重试或错误转换——错误转换在 `ApiClient` 里统一完成，
/// 避免同一件事有两个地方负责。
class RequestLogInterceptor extends Interceptor {
  /// 创建日志拦截器。
  RequestLogInterceptor({required this.logger, this.logBody = false});

  /// 日志出口。
  final AppLogger logger;

  /// 是否把请求体写进日志（默认关闭，避免泄漏敏感数据）。
  final bool logBody;

  static const String _startedAtKey = 'core_network.startedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = DateTime.now();
    final data = options.data;
    logger.debug(
      '→ ${options.method} ${options.uri}',
      context: logBody && data != null ? <String, Object?>{'body': data} : null,
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    logger.debug(
      '← ${response.statusCode} ${response.requestOptions.uri} '
      '(${_elapsedMs(response.requestOptions)}ms)',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.warn(
      '✗ ${err.requestOptions.method} ${err.requestOptions.uri} '
      '(${_elapsedMs(err.requestOptions)}ms)',
      error: err.error ?? err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }

  int _elapsedMs(RequestOptions options) {
    final startedAt = options.extra[_startedAtKey];
    return startedAt is DateTime
        ? DateTime.now().difference(startedAt).inMilliseconds
        : 0;
  }
}
