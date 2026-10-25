/// 当前标准上下文：UI 切换的是“标准族”（ISO/GB/ASME/SS_ISO），
/// 引擎按查询域解析为具体标准，并携带回退链（数值缺失时逐级回退并提示）。
class StandardContext {
  const StandardContext({
    required this.family,
    required this.primaryStandard,
    required this.fallbackChain,
  });

  final String family; // ISO / GB / ASME / SS_ISO
  final String primaryStandard; // 该族在尺寸公差域的主标准，如 ISO_286
  final List<String> fallbackChain; // 依次尝试的标准代号
}
