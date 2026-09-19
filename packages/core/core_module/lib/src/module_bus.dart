import 'package:core_error/core_error.dart';

import 'module_exception.dart';
import 'module_protocol.dart';
import 'module_registry.dart';

/// 应用内导航端口。
///
/// `core_module` 只声明它，实现放在 `core_router`（基于 go_router）或测试
/// 里的假对象中——模块系统因此不需要依赖 Flutter。
abstract interface class ModuleNavigator {
  /// 打开一个应用内位置（如 `/product/detail/10001`）。
  Future<void> open(String location);
}

/// 模块总线：模块之间唯一的「命令」通道。
///
/// 调用方只面对协议地址，不面对实现模块：
///
/// ```dart
/// await moduleBus.open('product://detail?id=10001');
/// ```
///
/// 总线负责三件事：解析地址 → 找到协议 → 把协议返回的意图落地。
/// 它**不**吞掉失败：所有异常都转成 [FailureResponse] 返回，方便调用方
/// 决定提示还是降级。
class ModuleBus {
  /// 用注册表与可选导航端口创建总线。
  ModuleBus({required this.registry, this.navigator});

  /// 协议与模块的来源。
  final ModuleRegistry registry;

  /// 跳转执行者；为 null 时遇到 [NavigationResponse] 会返回失败响应。
  final ModuleNavigator? navigator;

  /// 按协议地址调用某个模块。
  Future<ModuleResponse> open(
    String uri, {
    Map<String, Object?>? params,
  }) async {
    final request = ModuleRequest.parse(uri, params: params);
    final protocol = registry.protocolFor(request.scheme);
    if (protocol == null) {
      return ModuleResponse.failure(
        ModuleException(
          '没有模块能处理协议 scheme：${request.scheme}',
          code: 'module.protocol_not_found',
          cause: request.uri,
        ),
      );
    }

    ModuleResponse response;
    try {
      response = await protocol.handle(request);
    } on AppException catch (error) {
      return ModuleResponse.failure(error);
    } on Object catch (error, stackTrace) {
      return ModuleResponse.failure(
        ModuleException(
          '协议处理异常：$uri',
          code: 'module.protocol_failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }

    if (response is NavigationResponse) {
      final target = navigator;
      if (target == null) {
        return ModuleResponse.failure(
          ModuleException(
            '未注入 ModuleNavigator，无法跳转：${response.location}',
            code: 'module.navigator_missing',
          ),
        );
      }
      try {
        await target.open(response.location);
      } on Object catch (error, stackTrace) {
        return ModuleResponse.failure(
          ModuleException(
            '跳转失败：${response.location}',
            code: 'module.navigation_failed',
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
    }

    return response;
  }

  /// [scheme] 是否有模块提供协议。
  bool supports(String scheme) => registry.protocolFor(scheme) != null;
}
