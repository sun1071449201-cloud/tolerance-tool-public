import 'package:drift/drift.dart';

/// 反选求解规则参数（里程碑 3 使用；算法只读此表，不硬编码参数）。
class FitRecommendationRules extends Table {
  TextColumn get ruleId => text()();
  TextColumn get scopeStandard => text().nullable()(); // 空 = 全标准通用
  TextColumn get system => text()(); // hole_basis / shaft_basis
  TextColumn get fitType => text()(); // clearance / transition / interference
  TextColumn get gradePool => text()(); // JSON：{"hole":[...],"shaft":[...]}
  BoolColumn get preferredOnly => boolean().withDefault(const Constant(true))();
  TextColumn get scoring => text()(); // JSON：评分权重
  TextColumn get costHints => text()(); // JSON：等级 → 加工成本提示
  IntColumn get candidateLimit => integer().withDefault(const Constant(8))();
  TextColumn get reasonTemplates => text()(); // JSON：计算型理由段模板
  TextColumn get sourceRef => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {ruleId};
}
