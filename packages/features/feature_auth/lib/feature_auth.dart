/// 认证模块：账号密码登录、短信验证码登录、重置密码。
///
/// 对外只有两类东西：
/// * **模块契约**——[AuthModule] / [authModuleDescriptor]、跨模块事件
///   [LoginSucceededEvent]、寻址协议 [AuthProtocol]；
/// * **数据源端口**——应用作为组装根必须能实现 [AuthService] 才能接入真实
///   后端，而 [AuthException] / [SmsCodeReceipt] 是该端口契约的一部分。
///
/// 页面、Controller、校验器、仓库实现与假实现都是模块私有实现，不从这里
/// 导出；测试与演示请走 `package:feature_auth/testing.dart`。
library;

export 'src/data/datasources/auth_service.dart';
export 'src/domain/entities/sms_code_receipt.dart';
export 'src/domain/services/auth_failure.dart';
export 'src/module/auth_descriptor.dart';
export 'src/module/auth_events.dart';
export 'src/module/auth_module.dart';
export 'src/protocol/auth_protocol.dart';
