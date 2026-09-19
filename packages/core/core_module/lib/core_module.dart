/// 模块系统：模块契约、注册表、模块总线与事件总线。
///
/// 本包是自研模块化的核心，**不引入任何第三方模块化框架**。它保持纯 Dart
/// （不依赖 Flutter），因此注册表、总线、事件总线的测试不需要 widget 环境。
///
/// 依赖方向：
/// * `core_module` → `core_di`（模块通过 [ModuleRegistrar] 登记自身依赖）、
///   `core_error`；
/// * 路由相关能力由 `core_router` 通过 [ModuleContribution] 扩展接入，
///   因此本包不需要认识 `Widget` / `go_router`。
library;

export 'src/app_module.dart';
export 'src/event_bus.dart';
export 'src/module_bus.dart';
export 'src/module_contribution.dart';
export 'src/module_descriptor.dart';
export 'src/module_exception.dart';
export 'src/module_protocol.dart';
export 'src/module_registrar.dart';
export 'src/module_registry.dart';
