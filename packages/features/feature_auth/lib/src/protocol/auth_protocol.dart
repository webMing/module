import 'package:core_module/core_module.dart';

/// 认证模块的对外协议（`auth://...`）。
///
/// 实现刻意保持**纯翻译**：不依赖 DI、不直接操作导航、不产生副作用，
/// 只把请求翻译成 [ModuleResponse]，由 `ModuleBus` 负责把意图落地。
/// 这样协议对象可以 `const` 构造，也能脱离 Flutter 做单元测试。
class AuthProtocol implements ModuleProtocol {
  /// 创建认证协议。
  const AuthProtocol();

  @override
  String get scheme => 'auth';

  @override
  Future<ModuleResponse> handle(ModuleRequest request) async {
    switch (request.target) {
      case 'login':
      case '':
        return const ModuleResponse.navigate('/login');
      case 'reset-password':
      case 'resetPassword':
        return const ModuleResponse.navigate('/reset-password');
      default:
        return ModuleResponse.failure(
          ModuleException(
            '认证模块不支持的目标：${request.target}',
            code: 'auth.unknown_target',
          ),
        );
    }
  }
}
