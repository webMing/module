import 'package:core_module/core_module.dart';

/// 首页模块的寻址协议，scheme 为 `home`。
///
/// 协议只做**纯翻译**：把请求翻译成 [ModuleResponse]，不碰 DI、不操作导航。
/// 例如 `home://root` 被翻译成「跳到 `/home`」，具体落地由 `ModuleBus` 交给
/// 路由执行。因此该对象可以 `const` 构造，也能脱离 Flutter 单测。
class HomeProtocol implements ModuleProtocol {
  /// 创建协议。
  const HomeProtocol();

  @override
  String get scheme => 'home';

  @override
  Future<ModuleResponse> handle(ModuleRequest request) async {
    switch (request.target) {
      case 'root':
      case 'home':
      case '':
        return const ModuleResponse.navigate('/home');
      default:
        return ModuleResponse.failure(
          ModuleException(
            '首页模块不支持的目标：${request.target}',
            code: 'home.unknown_target',
          ),
        );
    }
  }
}
