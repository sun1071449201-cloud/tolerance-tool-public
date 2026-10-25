enum FitType { clearance, transition, interference }

extension FitTypeX on FitType {
  String get label => switch (this) {
        FitType.clearance => '间隙配合',
        FitType.transition => '过渡配合',
        FitType.interference => '过盈配合',
      };
}

/// 公差带代号，如 H7（孔）、g6（轴）。大小写字母区分孔轴。
class ZoneCode {
  const ZoneCode({required this.letter, required this.grade, required this.isHole});

  final String letter;
  final int grade;
  final bool isHole;

  String get code => '$letter$grade';
}

/// 一次公差代号的解析结果，如 ⌀50 H7/g6。
class ToleranceDesignation {
  const ToleranceDesignation({required this.nominalSize, required this.hole, this.shaft});

  final double nominalSize;
  final ZoneCode hole;
  final ZoneCode? shaft;

  String get display => shaft == null
      ? '⌀${_sizeText(nominalSize)} ${hole.code}'
      : '⌀${_sizeText(nominalSize)} ${hole.code}/${shaft!.code}';

  static String _sizeText(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();
}

/// 尺寸段（ISO 主分段）。
class SizeStepInfo {
  const SizeStepInfo({
    required this.stepId,
    required this.bracket,
    required this.lowerMm,
    required this.upperMm,
  });

  final String stepId;
  final String bracket;
  final double lowerMm;
  final double upperMm;
}

/// 基本偏差值：definedSide 为 'es' 或 'ei'，另一侧由 ±IT 推导；
/// oppositeUm 用于覆盖特殊值（如某些等级随等级变化的偏差）。
class DeviationValue {
  const DeviationValue({
    required this.definedSide,
    required this.deviationUm,
    this.oppositeUm,
  });

  final String definedSide;
  final int deviationUm;
  final int? oppositeUm;
}

/// 某公差带的极限偏差（μm，带符号）。upper = ES（孔）/ es（轴），lower = EI / ei。
class ZoneLimits {
  const ZoneLimits({required this.zone, required this.upperUm, required this.lowerUm});

  final ZoneCode zone;
  final int upperUm;
  final int lowerUm;
}

/// 一条配合极限结果（如“最大间隙 Xmax = +0.050”）。
class FitLimitTerm {
  const FitLimitTerm(this.label, this.um, {required this.isInterference});

  final String label;
  final int um;
  final bool isInterference; // 过盈量按正值表述
}

/// 尺寸公差与配合查询结果。
class FitQueryResult {
  const FitQueryResult({
    required this.input,
    required this.stepId,
    required this.stepBracket,
    required this.hole,
    this.shaft,
    this.fitType,
    required this.xMaxUm,
    required this.xMinUm,
    required this.standardUsed,
    required this.fallbackUsed,
    this.equivalenceTip,
  });

  final ToleranceDesignation input;
  final String stepId;
  final String stepBracket;
  final ZoneLimits hole;
  final ZoneLimits? shaft;

  /// Xmax = ES − ei（μm，带符号）；Xmin = EI − es。
  final int? xMaxUm;
  final int? xMinUm;
  final FitType? fitType;

  final String standardUsed; // 实际取到数值的标准代号
  final bool fallbackUsed; // 是否经过回退链复用了其他标准
  final String? equivalenceTip; // 等价复用提示（来自 knowledge_relations）

  bool get holeBasis => input.hole.letter == 'H';
  bool get shaftBasis => input.shaft?.letter == 'h';

  List<FitLimitTerm> get fitTerms {
    final xm = xMaxUm, xn = xMinUm;
    final type = fitType;
    if (type == null || xm == null || xn == null) return const [];
    switch (type) {
      case FitType.clearance:
        return [
          FitLimitTerm('最大间隙 Xmax', xm, isInterference: false),
          FitLimitTerm('最小间隙 Xmin', xn, isInterference: false),
        ];
      case FitType.transition:
        return [
          FitLimitTerm('最大间隙 Xmax', xm, isInterference: false),
          FitLimitTerm('最大过盈 Ymax', -xn, isInterference: true),
        ];
      case FitType.interference:
        return [
          FitLimitTerm('最大过盈 Ymax', -xn, isInterference: true),
          FitLimitTerm('最小过盈 Ymin', -xm, isInterference: true),
        ];
    }
  }
}
