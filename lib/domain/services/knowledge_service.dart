import 'dart:convert';

import '../models/knowledge_models.dart';
import '../models/standard_context.dart';
import '../models/tolerance_models.dart';
import '../ports/repositories.dart';

/// 知识关联引擎（里程碑 1 子集）：
/// 所有提示文案均取自 knowledge_relations / explanation_cards，代码只负责取数与拼装。
class KnowledgeService {
  KnowledgeService(this._repo);

  final KnowledgeRepository _repo;

  Future<List<KnowledgeTip>> tipsFor(FitQueryResult result, StandardContext ctx) async {
    final tips = <KnowledgeTip>[];

    // 1) 当前标准默认公差原则（PRINCIPLE_DEFAULT）
    final principle = await _repo.relationBySubject(
      type: 'PRINCIPLE_DEFAULT',
      subject: 'standard:${result.standardUsed}',
    );
    if (principle != null) {
      tips.add(KnowledgeTip(
        title: '当前标准默认公差原则',
        text: principle.statement,
        trace: 'knowledge_relations #${principle.id}',
        chapterKey: _chapterFromPayload(principle.payload),
        anchor: _anchorFromPayload(principle.payload),
      ));
    }

    // 2) 配合性质卡（EXPLANATION_CARD，按配合类型）
    if (result.fitType != null) {
      final card = await _cardForSubject('concept:fit_type:${result.fitType!.name}');
      if (card != null) {
        tips.add(KnowledgeTip(
          title: '配合性质 · ${card.title}',
          text: '${card.definition}\n工程意义：${card.engineering}',
          trace: card.trace,
          chapterKey: card.chapterKey,
          anchor: card.anchor,
        ));
      }
    }

    // 3) 基孔制说明（孔代号为 H 时）
    if (result.holeBasis) {
      final card = await _cardForSubject('concept:fit_system:hole_basis');
      if (card != null) {
        tips.add(KnowledgeTip(
          title: '知识点 · ${card.title}',
          text: '${card.definition}\n工程意义：${card.engineering}',
          trace: card.trace,
          chapterKey: card.chapterKey,
          anchor: card.anchor,
        ));
      }
    }

    // 4) H7 名词卡
    if (result.input.hole.letter == 'H' && result.input.hole.grade == 7) {
      final card = await _cardForSubject('term:H7');
      if (card != null) {
        tips.add(KnowledgeTip(
          title: '名词解释 · ${card.title}',
          text: card.definition,
          trace: card.trace,
          chapterKey: card.chapterKey,
          anchor: card.anchor,
        ));
      }
    }

    // 5) 标准等价提示（回退复用了其他标准的数值时）
    if (result.fallbackUsed && result.equivalenceTip != null) {
      final rel = await _repo.standardEquivalence(ctx.primaryStandard, result.standardUsed);
      tips.add(KnowledgeTip(
        title: '标准等价提示',
        text: result.equivalenceTip!,
        trace: 'knowledge_relations（STANDARD_EQUIVALENCE）',
        chapterKey: rel == null ? null : _chapterFromPayload(rel.payload),
        anchor: rel == null ? null : _anchorFromPayload(rel.payload),
      ));
    }

    return tips;
  }

  /// payload JSON 中的 chapter 字段 = 关联书籍章节键（如 qc_book.ch01）。
  String? _chapterFromPayload(String payload) => _payloadField(payload, 'chapter');

  /// payload JSON 中的 anchor 字段 = 章内节号锚点（如 "1.2.2"）。
  String? _anchorFromPayload(String payload) => _payloadField(payload, 'anchor');

  String? _payloadField(String payload, String field) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final v = decoded[field];
        if (v is String && v.isNotEmpty) return v;
      }
    } catch (_) {
      // payload 不是合法 JSON 时忽略
    }
    return null;
  }

  Future<_CardWithTrace?> _cardForSubject(String subjectRef) async {
    final rel = await _repo.relationBySubject(type: 'EXPLANATION_CARD', subject: subjectRef);
    if (rel == null) return null;
    final card = await _repo.cardByKey(_cardKey(rel.object));
    if (card == null) return null;
    return _CardWithTrace(
      card,
      'explanation_cards:${card.cardKey}（经 knowledge_relations #${rel.id}）',
      _chapterFromPayload(rel.payload),
      _anchorFromPayload(rel.payload),
    );
  }

  String? _cardKey(String? objectRef) {
    if (objectRef == null) return null;
    return objectRef.startsWith('card:') ? objectRef.substring(5) : null;
  }
}

class _CardWithTrace {
  const _CardWithTrace(this.card, this.trace, this.chapterKey, this.anchor);
  final CardRecord card;
  final String trace;
  final String? chapterKey;
  final String? anchor;

  String get title => card.title;
  String get definition => card.definition;
  String get engineering => card.engineering;
}
