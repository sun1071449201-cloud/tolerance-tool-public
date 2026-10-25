import 'package:drift/drift.dart';

/// 概念层：标准无关，只存语义标识，不存公差数值。

/// 尺寸段——中性“区间实体池”，可容纳多套分段集合（scope 区分），统一以 mm 存储。
class SizeSteps extends Table {
  TextColumn get stepId => text()();
  RealColumn get lowerMm => real()();
  RealColumn get upperMm => real()();
  TextColumn get bracket => text()(); // 显示用，如 “30~50”
  TextColumn get scope => text().nullable()(); // ISO_MAIN / ISO_GENTOL / ...
  IntColumn get sort => integer()();

  @override
  Set<Column> get primaryKey => {stepId};
}

/// 标准公差等级语义（IT01~IT18）。
class ItGrades extends Table {
  TextColumn get gradeId => text()();
  IntColumn get sort => integer()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {gradeId};
}

/// 基本偏差代号语义。zoneClass 为方位类别：
/// below(负区) / above(正区) / symmetric(±IT/2) / zero_lower(H：EI=0) /
/// zero_upper(h：es=0) / crossing(跨零线，如 k)。
class FundamentalDeviations extends Table {
  TextColumn get devId => text()(); // 大小写分行：h(轴) / H(孔)
  TextColumn get appliesTo => text()(); // shaft / hole
  TextColumn get zoneClass => text()();
  TextColumn get formulaNote => text().nullable()();

  @override
  Set<Column> get primaryKey => {devId};
}

/// 形位公差项目（14 项）。
class GdntItems extends Table {
  TextColumn get itemId => text()();
  TextColumn get symbol => text()();
  TextColumn get name => text()();
  TextColumn get category => text()(); // form / orientation / location / runout / profile
  BoolColumn get requiresDatum => boolean().withDefault(const Constant(false))();
  TextColumn get zoneShape => text()();
  TextColumn get featureType => text()();
  TextColumn get availability => text()(); // JSON：各标准是否可用（驱动标准差异提示）

  @override
  Set<Column> get primaryKey => {itemId};
}

/// 公差原则。
class TolerancePrinciples extends Table {
  TextColumn get principleId => text()();
  TextColumn get name => text()();
  TextColumn get shortSymbol => text().nullable()();
  TextColumn get definitionRef => text().nullable()();

  @override
  Set<Column> get primaryKey => {principleId};
}
