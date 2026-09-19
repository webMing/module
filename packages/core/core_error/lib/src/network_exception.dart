import 'package:meta/meta.dart';

import 'app_exception.dart';

/// 网络失败的归类，UI 可据此决定是否提供「重试」。
enum NetworkErrorKind {
  /// 连接超时或读写超时。
  timeout,

  /// 无网络 / 连接被拒绝 / DNS 失败。
  noConnection,

  /// 收到了响应但状态码非 2xx。
  badResponse,

  /// 请求被主动取消。
  cancelled,

  /// 响应无法解析（结构不符合预期）。
  badPayload,

  /// 未归类。
  unknown,
}

/// 网络层异常。
@immutable
final class NetworkException extends AppException {
  /// 创建一个网络异常。
  const NetworkException(
    super.message, {
    required this.kind,
    this.statusCode,
    this.uri,
    super.code,
    super.cause,
    super.stackTrace,
  });

  /// 失败归类。
  final NetworkErrorKind kind;

  /// HTTP 状态码，仅在 [NetworkErrorKind.badResponse] 时存在。
  final int? statusCode;

  /// 出错的请求地址。
  final Uri? uri;

  /// 是否值得让用户重试。
  bool get isRetryable =>
      kind == NetworkErrorKind.timeout ||
      kind == NetworkErrorKind.noConnection ||
      (statusCode != null && statusCode! >= 500);

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    buffer.write(' (kind: ${kind.name}');
    final code = statusCode;
    if (code != null) {
      buffer.write(', status: $code');
    }
    final target = uri;
    if (target != null) {
      buffer.write(', uri: $target');
    }
    buffer.write(')');
    return buffer.toString();
  }
}
