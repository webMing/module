import 'package:core_error/core_error.dart';
import 'package:core_logger/core_logger.dart';
import 'package:core_model/core_model.dart';
import 'package:dio/dio.dart';

import 'network_error_mapper.dart';

/// 面向业务的 HTTP 客户端。
///
/// 契约：
/// * 返回**解码后的数据**（[JsonMap] / [JsonList] / 原始值），不暴露
///   `Response`，避免 Dio 类型渗透进 feature；
/// * 任何失败都抛 [NetworkException]，调用方不需要 catch `DioException`。
class ApiClient {
  /// 创建客户端。
  ApiClient({required this.dio, AppLogger? logger})
    : logger = logger ?? const NoopLogger();

  /// 底层 Dio 实例（配置好 baseUrl 与拦截器）。
  final Dio dio;

  /// 日志出口。
  final AppLogger logger;

  /// GET 并断言响应体是对象。
  Future<JsonMap> getMap(String path, {Map<String, Object?>? query}) async =>
      _asMap(await send('GET', path, query: query), path);

  /// GET 并断言响应体是数组。
  Future<JsonList> getList(String path, {Map<String, Object?>? query}) async =>
      _asList(await send('GET', path, query: query), path);

  /// POST 并断言响应体是对象。
  Future<JsonMap> postMap(
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) async => _asMap(await send('POST', path, body: body, query: query), path);

  /// 发送请求，返回解码后的响应体。
  ///
  /// 失败时记录一条 warn 日志并抛出 [NetworkException]。
  Future<Object?> send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
  }) async {
    try {
      final response = await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
      );
      return response.data;
    } on DioException catch (error, stackTrace) {
      final failure = mapDioException(error, stackTrace: stackTrace);
      logger.warn(
        'API 调用失败：$method $path',
        error: failure,
        stackTrace: stackTrace,
        context: <String, Object?>{'code': failure.code},
      );
      throw failure;
    }
  }

  JsonMap _asMap(Object? data, String path) {
    if (data is Map) {
      return data.cast<String, Object?>();
    }
    throw _badPayload(path, data);
  }

  JsonList _asList(Object? data, String path) {
    if (data is List) {
      return List<Object?>.from(data);
    }
    throw _badPayload(path, data);
  }

  NetworkException _badPayload(String path, Object? data) => NetworkException(
    '响应结构不是预期类型',
    kind: NetworkErrorKind.badPayload,
    uri: Uri.tryParse('${dio.options.baseUrl}$path'),
    code: 'network.badPayload',
    cause: data,
  );
}
