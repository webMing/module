/// 会话契约：登录方式、会话模型与响应式会话存储。
///
/// 为什么这一层单独成包：架构约束「feature 之间不得相互依赖」，但登录结果
/// 必须被首页等多个模块读到。把会话契约下沉到 core，让 feature 各自依赖
/// core 而不是彼此，是同时满足两条约束的唯一做法。
library;

export 'src/auth_session.dart';
export 'src/login_method.dart';
export 'src/session_store.dart';
