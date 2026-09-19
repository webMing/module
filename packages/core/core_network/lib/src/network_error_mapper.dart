import 'package:core_error/core_error.dart';
import 'package:dio/dio.dart';

/// 把 [DioException] 归一化为 [NetworkException]。
///
/// 归一化的意义：上层模块只需要认识 [AppException] 一个体系，
/// 将来把 Dio 换成别的客户端时，feature 代码零改动。
NetworkException mapDioException(
  DioException error, {
  StackTrace? stackTrace,
}) {
  final options = error.requestOptions;
  final statusCode = error.response?.statusCode;
  final kind = _kindOf(error, statusCode);

  return NetworkException(
    describeNetworkError(kind, statusCode: statusCode),
    kind: kind,
    statusCode: statusCode,
    uri: options.uri,
    code: 'network.${kind.name}',
    cause: error.error ?? error,
    stackTrace: stackTrace ?? error.stackTrace,
  );
}

/// 面向用户的错误文案。
String describeNetworkError(NetworkErrorKind kind, {int? statusCode}) =>
    switch (kind) {
      NetworkErrorKind.timeout => '请求超时，请稍后重试',
      NetworkErrorKind.noConnection => '网络不可用，请检查网络连接',
      NetworkErrorKind.badResponse =>
        statusCode == null ? '服务返回异常' : '服务异常（HTTP $statusCode）',
      NetworkErrorKind.cancelled => '请求已取消',
      NetworkErrorKind.badPayload => '响应数据格式不正确',
      NetworkErrorKind.unknown => '网络请求失败',
    };

NetworkErrorKind _kindOf(DioException error, int? statusCode) =>
    switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      // dio 5.11 新增：响应体转换阶段超时，语义上仍是超时。
      DioExceptionType.transformTimeout =>
        NetworkErrorKind.timeout,
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate =>
        NetworkErrorKind.noConnection,
      DioExceptionType.cancel => NetworkErrorKind.cancelled,
      DioExceptionType.badResponse => NetworkErrorKind.badResponse,
      // unknown 且拿不到响应，多半是底层 socket / 解析异常。
      DioExceptionType.unknown =>
        statusCode == null
            ? NetworkErrorKind.unknown
            : NetworkErrorKind.badResponse,
    };
