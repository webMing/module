/// 依赖注入门面：封装 GetIt，供模块注册并取用自身依赖。
///
/// 模块只依赖 [ServiceLocator]，不直接 import `get_it`，将来更换容器实现
/// 时改动被限制在本包内。
library;

export 'src/service_locator.dart';
