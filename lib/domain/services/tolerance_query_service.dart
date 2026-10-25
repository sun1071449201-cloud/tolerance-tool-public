import '../../core/errors/exceptions.dart';
import '../../core/utils/format.dart';
import '../models/standard_context.dart';
import '../models/tolerance_models.dart';
import '../ports/repositories.dart';

/// 尺寸公差与配合查询：由 IT 值 + 基本偏差值推导极限偏差与配合，
/// 不存任何成品偏差表；数值缺失时沿回退链复用等价标准并给出提示。
class ToleranceQueryService {
  ToleranceQueryService(this._repo, this._knowledgeRepo);

  final ToleranceRepository _repo;
  final KnowledgeRepository _knowledgeRepo;

  Future<FitQueryResult> query(ToleranceDesignation input, StandardContext ctx) async {
    final step = await _repo.findStep(input.nominalSize);
    if (step == null) {
      throw DataNotSeedException(
          '基本尺寸 ${formatMm(input.nominalSize)} mm 不在已收录尺寸段（0~500 mm，ISO 主分段）内');
    }

    final hole = await _resolveZone(input.hole, step, ctx, input.nominalSize);
    final shaft = input.shaft == null
        ? null
        : await _resolveZone(input.shaft!, step, ctx, input.nominalSize);

    int? xMax;
    int? xMin;
    FitType? fitType;
    if (shaft != null) {
      xMax = hole.limits.upperUm - shaft.limits.lowerUm; // ES − ei
      xMin = hole.limits.lowerUm - shaft.limits.upperUm; // EI − es
      fitType = xMin >= 0
          ? FitType.clearance
          : (xMax <= 0 ? FitType.interference : FitType.transition);
    }

    return FitQueryResult(
      input: input,
      stepId: step.stepId,
      stepBracket: step.bracket,
      hole: hole.limits,
      shaft: shaft?.limits,
      fitType: fitType,
      xMaxUm: xMax,
      xMinUm: xMin,
      standardUsed: hole.standardUsed,
      fallbackUsed: hole.fallbackUsed,
      equivalenceTip: hole.equivalenceTip,
    );
  }

  Future<_ResolvedZone> _resolveZone(
      ZoneCode zone,
      SizeStepInfo step,
      StandardContext ctx,
      double nominalSize) async {
    final gradeId = 'IT${zone.grade}';
    for (final std in ctx.fallbackChain) {
      final it = await _repo.itValueUm(
          standardCode: std, stepId: step.stepId, gradeId: gradeId);
      if (it == null) continue;
      final dev = await _repo.deviationOverride(
            standardCode: std,
            devId: zone.letter,
            nominalSize: nominalSize,
          ) ??
          await _repo.deviationValue(
              standardCode: std, stepId: step.stepId, devId: zone.letter);
      if (dev == null) continue;

      // 孔系 K/M/N（IT≤8）和 P..ZC（IT≤7）的 ES 不是简单的轴系镜像：
      // ES = -ei + Δ，Δ = ITn − IT(n−1)。数据里存的是 -ei 基准值，
      // 这里按等级补 Δ；其余等级/字母仍按基准值走。
      var effective = dev;
      if (_holeDeltaApplies(zone) && zone.grade > 1) {
        final prevIt = await _repo.itValueUm(
          standardCode: std,
          stepId: step.stepId,
          gradeId: 'IT${zone.grade - 1}',
        );
        if (prevIt != null) {
          effective = DeviationValue(
            definedSide: dev.definedSide,
            deviationUm: dev.deviationUm + (it - prevIt),
            oppositeUm: dev.oppositeUm,
          );
        }
      }

      final limits = _limits(effective, it);
      final fallbackUsed = std != ctx.primaryStandard;
      String? tip;
      if (fallbackUsed) {
        final rel = await _knowledgeRepo.standardEquivalence(ctx.primaryStandard, std);
        tip = rel?.statement ?? '当前标准未收录该数值，已按回退链使用 $std 的数值';
      }
      return _ResolvedZone(
        ZoneLimits(zone: zone, upperUm: limits.$1, lowerUm: limits.$2),
        std,
        fallbackUsed,
        tip,
      );
    }
    throw DataNotSeedException(
      '代号 ${zone.code} 在尺寸段 ${step.bracket} mm 的数值未收录。\n'
      '当前数据集收录：IT5~IT12；轴代号 c/d/e/f/g/h/k/n/p（≤500 mm）、r/s/u（≤500 mm，按子段）；孔代号 H/K/N/P（≤500 mm）。\n'
      '补充方法：编辑 assets/data 中的种子 JSON（不编造标准值，待核对后替换）。',
    );
  }

  /// ISO 286-1 孔系等级例外：K/M/N 到 IT8、P..ZC 到 IT7 要加 Δ。
  bool _holeDeltaApplies(ZoneCode zone) {
    if (!zone.isHole) return false;
    switch (zone.letter) {
      case 'K':
      case 'M':
      case 'N':
        return zone.grade <= 8;
      case 'P':
      case 'R':
      case 'S':
      case 'T':
      case 'U':
      case 'V':
      case 'X':
      case 'Y':
      case 'Z':
      case 'ZA':
      case 'ZB':
      case 'ZC':
        return zone.grade <= 7;
      default:
        return false;
    }
  }

  /// (upper, lower) = (ES/es, EI/ei)。
  /// 孔：ES = EI + Th（A–H 定义侧为 EI）；轴：ei = es − Ts（a–h 定义侧为 es）、
  /// es = ei + Ts（j–zc 定义侧为 ei）；oppositeUm 覆盖特殊值。
  (int, int) _limits(DeviationValue dev, int itUm) {
    if (dev.oppositeUm != null) {
      return dev.definedSide == 'es'
          ? (dev.deviationUm, dev.oppositeUm!)
          : (dev.oppositeUm!, dev.deviationUm);
    }
    if (dev.definedSide == 'es') {
      return (dev.deviationUm, dev.deviationUm - itUm);
    }
    return (dev.deviationUm + itUm, dev.deviationUm);
  }
}

class _ResolvedZone {
  const _ResolvedZone(this.limits, this.standardUsed, this.fallbackUsed, this.equivalenceTip);

  final ZoneLimits limits;
  final String standardUsed;
  final bool fallbackUsed;
  final String? equivalenceTip;
}
