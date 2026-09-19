/// 核心错误体系：统一异常基类与各基础设施异常。
///
/// 业务代码只需要 `catch (AppException e)`，不必了解 Dio、存储插件等
/// 具体实现抛出的私有异常类型——各基础设施包负责把底层异常归一化为
/// [AppException] 的子类。
library;

export 'src/app_exception.dart';
export 'src/config_exception.dart';
export 'src/network_exception.dart';
export 'src/storage_exception.dart';
export 'src/unknown_exception.dart';
