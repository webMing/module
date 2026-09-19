/// 模块对系统的一项通用贡献（标记接口）。
///
/// 这个接口是「模块系统」与「具体能力包」之间的解耦点：`core_router` 定义
/// `RouteDefinition implements ModuleContribution`，于是路由能力可以插进
/// 注册表，而 `core_module` 完全不需要认识 Flutter 或 go_router。
///
/// 注意它是**空标记**：贡献对象不需要知道自己属于哪个模块——来源归属由
/// 收集它的 `ModuleRegistrar` 提供，避免每个贡献都携带一份重复的模块 id。
abstract interface class ModuleContribution {}
