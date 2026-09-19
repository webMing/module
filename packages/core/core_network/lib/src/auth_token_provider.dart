/// 访问令牌提供者。
///
/// 由应用装配层把 `SessionStore` 适配成这个端口注入网络层，
/// 于是 `core_network` 不需要依赖 `core_session`——
/// 依赖方向保持「网络能力 ← 会话契约」之外的单向。
abstract interface class AuthTokenProvider {
  /// 当前令牌；未登录时为 null。
  String? get token;
}
