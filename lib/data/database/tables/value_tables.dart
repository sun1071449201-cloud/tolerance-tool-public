import 'package:drift/drift.dart';

/// 标准值层：每行带 standard_code；IT 与偏差为整数 μm，形位为 REAL mm。
/// 所有行默认 verified=false（占位待人工核对）。

class ItToleranceValues extends Table {
  TextColumn get standardCode => text()();
  TextColumn get stepId => text()();
  TextColumn get gradeId => text()();
  IntColumn get valueUm => integer()();
  TextColumn get sourceRef => text()();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {standardCode, stepId, gradeId};
}

/// defined_side：该代号在该尺寸段“定义”的偏差侧（es 或 ei），
/// 另一侧由引擎用 ±IT 推导；opposite_um 覆盖特殊值。
class FundamentalDeviationValues extends Table {
  TextColumn get standardCode => text()();
  TextColumn get stepId => text()();
  TextColumn get devId => text()();
  TextColumn get definedSide => text()();
  IntColumn get deviationUm => integer()();
  IntColumn get oppositeUm => integer().nullable()();
  TextColumn get sourceRef => text()();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {standardCode, stepId, devId};
}

/// 形位公差注出值（项目 × 等级 1~12 × 主参数段）。主来源 MANUAL_GDT。
class GdntGradeValues extends Table {
  TextColumn get standardCode => text()();
  TextColumn get itemId => text()();
  IntColumn get gradeIndex => integer()();
  TextColumn get stepId => text()();
  RealColumn get valueMm => real()();
  TextColumn get sourceRef => text()();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {standardCode, itemId, gradeIndex, stepId};
}

/// 优先/常用配合：只存组合与用途，数值由 IT/偏差表推导。
class PreferredFits extends Table {
  TextColumn get standardCode => text()();
  TextColumn get system => text()(); // hole_basis / shaft_basis
  TextColumn get fitType => text()(); // clearance / transition / interference
  TextColumn get holeDev => text()();
  IntColumn get holeGrade => integer()();
  TextColumn get shaftDev => text()();
  IntColumn get shaftGrade => integer()();
  TextColumn get usageTag => text()(); // preferred / common / general
  TextColumn get usageNote => text().nullable()();

  @override
  Set<Column> get primaryKey =>
      {standardCode, system, holeDev, holeGrade, shaftDev, shaftGrade};
}

/// 未注公差等级（GB/T 1804 ↔ ISO 2768 的 f/m/c/v，GB/T 1184 ↔ ISO 2768-2 的 H/K/L）。
class GeneralTolerances extends Table {
  TextColumn get standardCode => text()();
  TextColumn get classCode => text()(); // f/m/c/v 或 H/K/L
  TextColumn get kind => text()(); // linear / angle / flatness / ...
  TextColumn get stepId => text()();
  RealColumn get value => real()();
  TextColumn get unit => text()(); // mm / °
  TextColumn get sourceRef => text()();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {standardCode, classCode, kind, stepId};
}

/// 数值等价映射（数据级复用与回退依据）。
class ValueEquivalences extends Table {
  TextColumn get equivId => text()();
  TextColumn get sourceStandard => text()();
  TextColumn get targetStandard => text()();
  TextColumn get direction => text()(); // bidirectional / one_way
  TextColumn get appliesTo => text()(); // JSON：适用的表
  TextColumn get mapping => text()(); // JSON：{"*":"*"} 或等级映射
  TextColumn get statement => text()(); // 复用时的提示文案
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {equivId};
}
/// 基本偏差子尺寸段覆盖（S/r/u 等在 120~500 内部还有细分段）。
class FundamentalDeviationOverrides extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get standardCode => text()();
  TextColumn get devId => text()();
  RealColumn get lowerMm => real()();
  RealColumn get upperMm => real()();
  TextColumn get definedSide => text()();
  IntColumn get deviationUm => integer()();
  TextColumn get sourceRef => text()();
  BoolColumn get verified => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [{standardCode, devId, lowerMm, upperMm}];
}
