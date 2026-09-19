import 'package:meta/meta.dart';

import 'app_exception.dart';

/// 持久化异常：读写失败、数据损坏或不可用。
@immutable
final class StorageException extends AppException {
  /// 创建一个持久化异常。
  const StorageException(
    super.message, {
    this.key,
    super.code,
    super.cause,
    super.stackTrace,
  });

  /// 出错的存储键。
  final String? key;

  @override
  String toString() {
    final buffer = StringBuffer(super.toString());
    final target = key;
    if (target != null) {
      buffer.write(' (key: $target)');
    }
    return buffer.toString();
  }
}
