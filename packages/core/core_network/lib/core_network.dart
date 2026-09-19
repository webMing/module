/// 网络能力：Dio 装配、拦截器与错误归一化。
///
/// 模块通过 [ApiClient] 发请求，拿到的是解码后的 JSON 与
/// `NetworkException`，不直接接触 Dio 类型。
library;

export 'src/api_client.dart';
export 'src/auth_token_provider.dart';
export 'src/interceptors.dart';
export 'src/network_error_mapper.dart';
export 'src/network_factory.dart';
