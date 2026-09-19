import 'package:meta/meta.dart';

import 'app_exception.dart';

/// 配置异常：缺少必填项或取值非法。
///
/// 该异常应当在启动阶段（Bootstrap）就抛出，而不是等到第一次发请求。
@immutable
final class ConfigException extends AppException {
  /// 创建一个配置异常。
  const ConfigException(
    super.message, {
    this.key,
    super.code,
    super.cause,
    super.stackTrace,
  });

  /// 出错的配置项名称。
  final String? key;

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    final name = key;
    if (name != null) {
      buffer.write(' (key: $name)');
    }
    return buffer.toString();
  }
}
