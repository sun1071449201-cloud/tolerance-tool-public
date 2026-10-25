import 'package:drift/drift.dart';

/// 工程速查与选型条目（FTS 全文检索数据源；tip 为关联经验卡片）。
class QuickRefItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get refId => text().unique()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  TextColumn get contentMd => text()();
  TextColumn get keywords => text()();
  TextColumn get tip => text()();
  TextColumn get sourceRef => text().nullable()(); // 经验卡参考来源
}