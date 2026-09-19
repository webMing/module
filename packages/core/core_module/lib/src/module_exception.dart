import 'package:core_error/core_error.dart';
import 'package:meta/meta.dart';

/// 模块系统自身的异常（协议缺失、跳转端口未注入等）。
@immutable
final class ModuleException extends AppException {
  /// 创建一个模块系统异常。
  const ModuleException(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
  });
}
