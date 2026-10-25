import 'package:drift/drift.dart';

/// 标准注册表。family='MANUAL' 的行是“机械设计手册”虚拟来源
/// （形位注出值表的合法数值来源，因 ISO 1101 / ASME Y14.5 原文不含注出值表）。
class Standards extends Table {
  TextColumn get standardCode => text()();
  TextColumn get displayName => text()();
  TextColumn get family => text()(); // ISO / GB / ASME / SS_ISO / MANUAL
  TextColumn get domain => text()(); // dimension / gdnt / general
  TextColumn get fallbackStandardCode => text().nullable()();
  TextColumn get dataStatus => text().withDefault(const Constant('placeholder'))();
  TextColumn get sourceNote => text().nullable()();

  @override
  Set<Column> get primaryKey => {standardCode};
}

/// 标准族 → 各查询域具体标准 + 回退链（全局标准切换的解析依据）。
class StandardFamilyMap extends Table {
  TextColumn get family => text()();
  TextColumn get domain => text()();
  TextColumn get primaryStandard => text()();
  TextColumn get fallbackChain => text()(); // JSON 数组
  TextColumn get switchNote => text().nullable()();

  @override
  Set<Column> get primaryKey => {family, domain};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}

class SeedMeta extends Table {
  TextColumn get datasetName => text()();
  TextColumn get version => text()();
  TextColumn get checksum => text()();
  DateTimeColumn get importedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {datasetName};
}
