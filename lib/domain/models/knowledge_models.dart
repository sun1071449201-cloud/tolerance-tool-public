/// 一条知识提示（文案与出处均来自 knowledge_relations / explanation_cards 表，
/// 代码中不硬编码任何提示文案）。
class KnowledgeTip {
  const KnowledgeTip({
    required this.title,
    required this.text,
    required this.trace,
    this.chapterKey,
    this.anchor,
  });

  final String title;
  final String text;

  /// 追溯信息，如 “knowledge_relations #9” 或 “explanation_cards:fit_clearance”。
  final String trace;

  /// 关联书籍章节键（payload.chapter），非空时知识卡显示“去书籍中查看完整解析”。
  final String? chapterKey;

  /// 章内节号锚点（payload.anchor，如 "1.2.2"），实现段级精准定位。
  final String? anchor;
}

/// 每日知识点（推荐池 = daily_facts ∪ EXPLANATION_CARD ∪ 速查经验卡 ∪ 设计常识）。
class DailyTip {
  const DailyTip({
    required this.title,
    required this.text,
    required this.trace,
    required this.sourceLabel,
    this.chapterKey = '',
    this.anchor,
    this.quickRefId,
  });

  final String title;
  final String text;

  /// 书籍章节键；速查经验卡与常识条目为空串，用 quickRefId 跳转。
  final String chapterKey;
  final String? anchor;

  /// 速查条目 ref_id（非空时点击打开速查详情）。
  final String? quickRefId;

  /// 来源标签：系统知识 / 我的笔记 / 速查经验。
  final String sourceLabel;
  final String trace;
}

/// knowledge_relations 表的一条关系记录。
class RelationRecord {
  const RelationRecord({
    required this.id,
    required this.type,
    required this.subject,
    this.object,
    required this.predicate,
    required this.payload,
    required this.statement,
    this.severity,
  });

  final int id;
  final String type;
  final String subject;
  final String? object;
  final String predicate;
  final String payload;
  final String statement;
  final String? severity;
}

/// explanation_cards 表的一张名词卡片。
class CardRecord {
  const CardRecord({
    required this.cardKey,
    required this.title,
    required this.definition,
    required this.engineering,
    this.standardDiff,
  });

  final String cardKey;
  final String title;
  final String definition;
  final String engineering;
  final String? standardDiff;
}
