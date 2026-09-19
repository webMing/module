import 'package:core_error/core_error.dart';
import 'package:meta/meta.dart';

/// 模块间寻址协议（「我要让你做事情」）。
///
/// 实现应当是**纯翻译**：不依赖 DI、不直接操作导航，只把请求翻译成一个
/// [ModuleResponse]（例如「跳到 `/product/detail/:id`」），由 `ModuleBus`
/// 负责把意图落地。好处是协议对象可以 `const` 构造，也能脱离 Flutter
/// 做单元测试。
abstract interface class ModuleProtocol {
  /// 本协议处理的 URI scheme（如 `product`）。
  String get scheme;

  /// 处理一次请求。
  Future<ModuleResponse> handle(ModuleRequest request);
}

/// 一次模块协议请求。
///
/// 由 `product://detail?id=10001` 这样的地址解析而来：[uri] 保留原始语义，
/// [params] 是 URI query 与调用方显式传入参数的合并结果（显式参数优先）。
@immutable
class ModuleRequest {
  /// 直接构造请求。
  const ModuleRequest({required this.uri, required this.params});

  /// 解析协议地址。
  ///
  /// 没有 scheme 的地址（如 `/login`）会在解析阶段直接失败——它应该走
  /// go_router，而不是模块总线。
  factory ModuleRequest.parse(String raw, {Map<String, Object?>? params}) {
    final uri = Uri.parse(raw);
    if (uri.scheme.isEmpty) {
      throw ArgumentError.value(
        raw,
        'raw',
        '模块协议地址必须带 scheme，例如 product://detail?id=10001',
      );
    }
    return ModuleRequest(
      uri: uri,
      params: <String, Object?>{...uri.queryParameters, ...?params},
    );
  }

  /// 原始地址。
  final Uri uri;

  /// 合并后的参数。
  final Map<String, Object?> params;

  /// 协议 scheme（如 `product`）。
  String get scheme => uri.scheme;

  /// 协议目标（`product://detail` 里的 `detail`）。
  String get target =>
      uri.host.isNotEmpty ? uri.host : uri.path.replaceFirst('/', '');

  /// 读取参数并断言类型，类型不符或缺失时返回 null。
  T? param<T extends String>(String key) {
    final value = params[key];
    return value is T ? value : null;
  }

  @override
  String toString() => 'ModuleRequest($uri, params: $params)';
}

/// 协议处理结果。
@immutable
sealed class ModuleResponse {
  /// 基类构造。
  const ModuleResponse();

  /// 请求转发到应用内某个路由。
  const factory ModuleResponse.navigate(
    String path, {
    Map<String, String> params,
    Map<String, Object?>? extra,
  }) = NavigationResponse;

  /// 返回一个值。
  const factory ModuleResponse.value(Object? value) = ValueResponse;

  /// 副作用已完成，无返回值。
  const factory ModuleResponse.done() = DoneResponse;

  /// 处理失败。
  const factory ModuleResponse.failure(AppException error) = FailureResponse;
}

/// 跳转响应。
@immutable
final class NavigationResponse extends ModuleResponse {
  /// 创建跳转响应。
  const NavigationResponse(
    this.path, {
    this.params = const <String, String>{},
    this.extra,
  });

  /// 目标路径，可含路径参数占位符（如 `/product/detail/:id`）。
  final String path;

  /// 用于填充路径占位符的参数；未消费的参数会追加为 query。
  final Map<String, String> params;

  /// 额外载荷（不参与地址拼接）。
  final Map<String, Object?>? extra;

  /// 最终跳转地址。
  String get location => buildLocation(path, params);

  @override
  String toString() => 'NavigationResponse($location)';
}

/// 带值的响应。
@immutable
final class ValueResponse extends ModuleResponse {
  /// 创建带值响应。
  const ValueResponse(this.value);

  /// 返回值。
  final Object? value;

  @override
  String toString() => 'ValueResponse($value)';
}

/// 空响应。
@immutable
final class DoneResponse extends ModuleResponse {
  /// 创建空响应。
  const DoneResponse();

  @override
  String toString() => 'DoneResponse()';
}

/// 失败响应。
@immutable
final class FailureResponse extends ModuleResponse {
  /// 创建失败响应。
  const FailureResponse(this.error);

  /// 失败原因。
  final AppException error;

  @override
  String toString() => 'FailureResponse($error)';
}

/// 用 [params] 填充 [path] 中的 `:name` 占位符。
///
/// 未被占位符消费的参数会作为 query 追加，因此协议实现可以只声明路径，
/// 其余参数自动透传（对深链尤其重要：外部链接常带一堆查询参数）。
String buildLocation(String path, [Map<String, String> params = const {}]) {
  var location = path;
  final consumed = <String>{};

  for (final entry in params.entries) {
    final token = ':${entry.key}';
    if (location.contains(token)) {
      location = location.replaceAll(token, Uri.encodeComponent(entry.value));
      consumed.add(entry.key);
    }
  }

  final rest = <String, String>{
    for (final entry in params.entries)
      if (!consumed.contains(entry.key)) entry.key: entry.value,
  };
  if (rest.isEmpty) {
    return location;
  }
  return '$location?${Uri(queryParameters: rest).query}';
}
