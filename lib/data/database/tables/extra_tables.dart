import 'package:drift/drift.dart';

/// 机械英语词库（FTS 全文检索的数据源，中英双向搜索）。
class VocabWords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get en => text()();
  TextColumn get zh => text()();
  TextColumn get category => text()();
  TextColumn get example => text().nullable()();
}

/// 每日知识点推荐池（精炼工程常识，关联书籍章节+节号锚点）。
class DailyFacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get body => text()(); // 注意：列名不能用 text（与 Drift Table API 冲突）
  TextColumn get chapterKey => text()();
  TextColumn get anchor => text().nullable()();
  TextColumn get source => text().nullable()();
}
