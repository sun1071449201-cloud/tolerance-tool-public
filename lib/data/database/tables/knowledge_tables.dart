import 'package:drift/drift.dart';

/// 知识关联层：全应用学习提示与校验规则的唯一来源。

/// 引用语法：gdnt_item:PARL / gdnt_category:form / standard:ISO_286 /
/// principle:INDEPENDENCE / concept:fit_system:hole_basis /
/// concept:fit_type:clearance / term:H7 / card:<card_key>
class KnowledgeRelations extends Table {
  IntColumn get relationId => integer().autoIncrement()();
  TextColumn get relationType => text()(); // NUMERIC_CONSTRAINT /
  // TOLERANCE_ZONE_CONTAINMENT / PRINCIPLE_DEFAULT / STANDARD_EQUIVALENCE /
  // EXPLANATION_CARD（可扩展）
  TextColumn get subjectRef => text()();
  TextColumn get objectRef => text().nullable()();
  TextColumn get scopeStandard => text().nullable()();
  TextColumn get predicate => text()(); // less_than / zone_contains /
  // default_principle / equivalent_values / explains / category_order ...
  TextColumn get payload => text()(); // JSON：谓词参数
  TextColumn get statement => text()(); // 结论/提示文案模板
  TextColumn get severity => text().nullable()(); // info / warn / error
  TextColumn get sourceRef => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
}

/// 名词解释卡片（正文来自 assets/data/explanation_cards.json，与查询逻辑解耦）。
class ExplanationCards extends Table {
  TextColumn get cardKey => text()();
  TextColumn get title => text()();
  TextColumn get definitionMd => text()();
  TextColumn get engineeringMd => text()(); // 一条工程意义
  TextColumn get standardDiffMd => text().nullable()(); // 相关标准差异
  TextColumn get relatedRefs => text()(); // JSON 数组
  TextColumn get tags => text()(); // JSON 数组（推荐理由 tag 匹配用）
  TextColumn get sourceRef => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {cardKey};
}
