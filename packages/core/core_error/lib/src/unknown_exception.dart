import 'package:meta/meta.dart';

import 'app_exception.dart';

/// 未归类异常的兜底包装。
///
/// 归一化时若无法判断底层异常类型，用它包一层，保证上层始终只需处理
/// [AppException]，同时不丢失原始 [cause]。
@immutable
final class UnknownException extends AppException {
  /// 创建一个兜底异常。
  const UnknownException(
    super.message, {
    super.code,
    super.cause,
    super.stackTrace,
  });
}
