import 'dart:convert';

import '../../data/database/app_database.dart';
import '../models/standard_context.dart';
import '../models/tolerance_models.dart';
import '../ports/repositories.dart';

/// 反选求解结果：一个候选配合 + 匹配度 + 推荐理由段。
class FitCandidate {
  const FitCandidate({
    required this.code,
    required this.fitType,
    required this.xMaxUm,
    required this.xMinUm,
    required this.score,
    required this.reasons,
  });

  final String code; // 如 H7/g6
  final FitType fitType;
  final int xMaxUm; // 带符号（负=过盈）
  final int xMinUm;
  final double score; // 0~1
  final List<ReasonSegment> reasons;
}

/// 推荐理由段（可追溯：relation_id / rule_id）。
class ReasonSegment {
  const ReasonSegment({
    required this.kind,
    required this.text,
    required this.trace,
  });

  final String kind; // fit_nature / default_principle / deviation_note / engineering_tip
  final String text;
  final String trace;
}

/// 反选求解：输入基本尺寸 + 配合类型 + 期望范围 → 推荐标准基孔制配合。
/// 全部规则参数（等级池/权重/成本提示/理由模板）来自 fit_recommendation_rules 表，
/// 不硬编码在算法里。
class FitSolverService {
  FitSolverService(this._toleranceRepo, this._knowledgeRepo, this._db);

  final ToleranceRepository _toleranceRepo;
  final KnowledgeRepository _knowledgeRepo;
  final AppDatabase _db;

  Future<List<FitCandidate>> solve({
    required double nominalSize,
    required String fitType, // clearance / transition / interference
    required int targetMinUm,
    required int targetMaxUm,
    required StandardContext ctx,
  }) async {
    // 1) 读规则行（scope 命中当前标准或通用）
    final rules = await _db.select(_db.fitRecommendationRules).get();
    final rule = rules
        .where((r) =>
            r.enabled &&
            r.fitType == fitType &&
            r.system == 'hole_basis' &&
            (r.scopeStandard == null || r.scopeStandard!.isEmpty))
        .firstOrNull;
    if (rule == null) return const [];

    final scoring =
        jsonDecode(rule.scoring) as Map<String, dynamic>;
    final costHints =
        jsonDecode(rule.costHints) as Map<String, dynamic>;
    final templates =
        jsonDecode(rule.reasonTemplates) as Map<String, dynamic>;

    // 2) 候选 = preferred_fits（当前标准回退链内）
    final fits = await _db.select(_db.preferredFits).get();
    final chain = ctx.fallbackChain.toSet();

    // 3) 逐个解算
    final results = <FitCandidate>[];
    for (final f in fits.where((f) => chain.contains(f.standardCode))) {
      if (rule.preferredOnly && f.usageTag != 'preferred') continue;
      final hole = ZoneCode(letter: f.holeDev, grade: f.holeGrade, isHole: true);
      final shaft = ZoneCode(letter: f.shaftDev, grade: f.shaftGrade, isHole: false);
      final cand = await _evaluate(
        nominalSize,
        '${hole.code}/${shaft.code}',
        hole,
        shaft,
        fitType,
        targetMinUm,
        targetMaxUm,
        ctx,
        scoring,
        costHints,
        templates,
      );
      if (cand != null) results.add(cand);
    }

    // 4) 按匹配度排序，取前 N
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(rule.candidateLimit).toList();
  }

  Future<FitCandidate?> _evaluate(
    double nominalSize,
    String code,
    ZoneCode hole,
    ZoneCode shaft,
    String fitType,
    int targetMin,
    int targetMax,
    StandardContext ctx,
    Map<String, dynamic> scoring,
    Map<String, dynamic> costHints,
    Map<String, dynamic> templates,
  ) async {
    final step = await _toleranceRepo.findStep(nominalSize);
    if (step == null) return null;

    // 沿回退链取 IT 值与基本偏差
    int? holeIt, shaftIt;
    DeviationValue? holeDev, shaftDev;
    String stdUsed = ctx.primaryStandard;
    for (final std in ctx.fallbackChain) {
      holeIt ??= await _toleranceRepo.itValueUm(
          standardCode: std, stepId: step.stepId, gradeId: 'IT${hole.grade}');
      shaftIt ??= await _toleranceRepo.itValueUm(
          standardCode: std, stepId: step.stepId, gradeId: 'IT${shaft.grade}');
      holeDev ??= await _toleranceRepo.deviationValue(
          standardCode: std, stepId: step.stepId, devId: hole.letter);
      shaftDev ??= await _toleranceRepo.deviationValue(
          standardCode: std, stepId: step.stepId, devId: shaft.letter);
      if (holeIt != null && shaftIt != null && holeDev != null && shaftDev != null) {
        stdUsed = std;
        break;
      }
    }
    if (holeIt == null || shaftIt == null || holeDev == null || shaftDev == null) {
      return null; // 数据未收录，不编造
    }

    // 推导极限偏差
    final holeEs = holeDev.definedSide == 'es'
        ? holeDev.deviationUm
        : (holeDev.oppositeUm ?? holeDev.deviationUm + holeIt);
    final holeEi = holeDev.definedSide == 'es'
        ? (holeDev.oppositeUm ?? holeDev.deviationUm - holeIt)
        : holeDev.deviationUm;
    final shaftEs = shaftDev.definedSide == 'es'
        ? shaftDev.deviationUm
        : (shaftDev.oppositeUm ?? shaftDev.deviationUm + shaftIt);
    final shaftEi = shaftDev.definedSide == 'es'
        ? (shaftDev.oppositeUm ?? shaftDev.deviationUm - shaftIt)
        : shaftDev.deviationUm;

    final xMax = holeEs - shaftEi;
    final xMin = holeEi - shaftEs;

    // 配合类型核对：候选实际类型必须与请求一致
    final actualType = xMin >= 0
        ? 'clearance'
        : (xMax <= 0 ? 'interference' : 'transition');
    if (actualType != fitType) return null;

    // 评分
    var score = 0.0;
    final overlap = _overlapRatio(xMin, xMax, targetMin, targetMax);
    final wIn = (scoring['in_range'] as num?)?.toDouble() ?? 1.0;
    final wOverlap = (scoring['overlap'] as num?)?.toDouble() ?? 0.6;
    if (xMin >= targetMin && xMax <= targetMax) {
      score = wIn;
    } else {
      score = wOverlap * overlap;
    }
    // 经济性：等级和越小越经济（轻微加权）
    final wEco = (scoring['economy'] as num?)?.toDouble() ?? 0.25;
    score += wEco * (1 / (1 + hole.grade + shaft.grade));

    // 推荐理由段（全部可追溯）
    final reasons = <ReasonSegment>[];
    final label = _fitTypeLabel(fitType);
    final rangeText = '${_um(xMin)} ~ ${_um(xMax)}';
    reasons.add(ReasonSegment(
      kind: 'fit_nature',
      text: '配合性质：$label，$code 的极限范围为 $rangeText μm。',
      trace: 'preferred_fits:$stdUsed',
    ));

    final principle = await _knowledgeRepo.relationBySubject(
      type: 'PRINCIPLE_DEFAULT',
      subject: 'standard:$stdUsed',
    );
    if (principle != null) {
      reasons.add(ReasonSegment(
        kind: 'default_principle',
        text: principle.statement,
        trace: 'knowledge_relations #${principle.id}',
      ));
    }

    final delta = _deltaFromTarget(xMin, xMax, targetMin, targetMax);
    final tpl = templates['deviation_note'] as String? ?? '';
    reasons.add(ReasonSegment(
      kind: 'deviation_note',
      text: tpl
          .replaceAll('{x_min}', _um(xMin))
          .replaceAll('{x_max}', _um(xMax))
          .replaceAll('{s_lo}', _um(targetMin))
          .replaceAll('{s_hi}', _um(targetMax))
          .replaceAll('{delta}', delta.abs().toString()),
      trace: 'fit_recommendation_rules:$fitType',
    ));

    final costHole = costHints['${hole.grade}'] as String?;
    final costShaft = costHints['${shaft.grade}'] as String?;
    reasons.add(ReasonSegment(
      kind: 'engineering_tip',
      text: '加工成本：孔 IT${hole.grade}'
          '${costHole == null ? '' : '（$costHole）'}，'
          '轴 IT${shaft.grade}${costShaft == null ? '' : '（$costShaft）'}。',
      trace: 'fit_recommendation_rules:$fitType',
    ));

    return FitCandidate(
      code: code,
      fitType: _parseFitType(fitType),
      xMaxUm: xMax,
      xMinUm: xMin,
      score: score,
      reasons: reasons,
    );
  }

  double _overlapRatio(int aMin, int aMax, int bMin, int bMax) {
    final lo = aMin > bMin ? aMin : bMin;
    final hi = aMax < bMax ? aMax : bMax;
    if (hi <= lo) return 0;
    final aSpan = (aMax - aMin) == 0 ? 1 : (aMax - aMin);
    return (hi - lo) / aSpan;
  }

  int _deltaFromTarget(int aMin, int aMax, int bMin, int bMax) {
    if (aMin >= bMin && aMax <= bMax) return 0;
    final d1 = (aMin - bMin).abs();
    final d2 = (aMax - bMax).abs();
    return d1 > d2 ? d1 : d2;
  }

  String _fitTypeLabel(String t) => switch (t) {
        'clearance' => '间隙配合',
        'transition' => '过渡配合',
        'interference' => '过盈配合',
        _ => t,
      };

  FitType _parseFitType(String t) => switch (t) {
        'clearance' => FitType.clearance,
        'transition' => FitType.transition,
        _ => FitType.interference,
      };

  String _um(int v) =>
      v >= 0 ? '+$v' : '$v';
}
