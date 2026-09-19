/// 测试与演示用的入口：只导出可替换的假实现，不参与生产装配。
///
/// 生产代码请只依赖 `package:feature_auth/feature_auth.dart`；应用外壳在
/// 端到端测试或本地演示时，从这里取 [FakeAuthService] 注册到容器，即可得到
/// 零延迟、可预测的认证行为。
library;

export 'src/data/datasources/fake_auth_service.dart';
