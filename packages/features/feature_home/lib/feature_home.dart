/// 首页模块。
///
/// 公开面只有模块与协议两层：
/// * [HomeModule] / [homeModuleDescriptor]：模块身份与装配入口；
/// * [HomeProtocol]：模块间寻址协议（scheme 为 `home`）；
/// * [LogoutRequestedEvent]：跨模块事件。
///
/// 页面与路由属于模块私有实现，不从这里导出：外部只能通过 `home://` 协议
/// 或 `/home` 路由到达首页，从而保证跨模块只依赖协议与事件。
library;

export 'src/module/home_descriptor.dart';
export 'src/module/home_events.dart';
export 'src/module/home_module.dart';
export 'src/protocol/home_protocol.dart';
