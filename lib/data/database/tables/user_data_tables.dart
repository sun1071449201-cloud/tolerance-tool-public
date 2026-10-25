import 'package:drift/drift.dart';

/// 阅读进度：每本书每章的最后滚动位置（用户数据，不随种子导入清库）。
class ReadingProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  TextColumn get chapterKey => text()();
  RealColumn get offsetPx => real().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{bookId, chapterKey}];
}

/// 书签：任意分段 + 备注（用户数据）。
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text()();
  TextColumn get chapterKey => text()();
  IntColumn get segmentIndex => integer().withDefault(const Constant(0))();
  TextColumn get excerpt => text()(); // 书签处文字摘要
  TextColumn get note => text().nullable()();
  TextColumn get anchor => text().nullable()(); // 节号锚点，内容改动后仍能定位 // 用户备注
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 章节已读标记（用户数据）。
class ChapterReadMarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get chapterKey => text().unique()();
  BoolColumn get isRead => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// 机械设计常识与禁忌（AI 知识库 + 自定义导入共用，全部进每日推荐池）。
class DesignTips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get category => text()();
  TextColumn get chapterKey => text().nullable()(); // 可关联书籍章节
  TextColumn get anchor => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))(); // 自定义导入标记
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 收藏条目（查询结果 / 速查 / 书籍章节均可收藏）。
class Favorites extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kind => text()(); // tolerance / vocab / chapter / quickref
  TextColumn get title => text()();
  TextColumn get subtitle => text()();
  TextColumn get targetKey => text()(); // 查询代号 / 词库en / 章节键 / 速查ref_id
  TextColumn get targetAnchor => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 公差查询历史（最近使用，供快速重查与清理）。
class QueryHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get queryText => text()();
  TextColumn get resultSummary => text()(); // 一行结果摘要
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
/// 英语背诵进度（用户数据，种子导入不清除）。
/// status: 0=未学，1=还不熟，2=已背。
class VocabProgress extends Table {
  IntColumn get wordId => integer()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get seenCount => integer().withDefault(const Constant(0))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {wordId};
}
/// 每日知识点历史：30 天内不重复推荐（用户数据）。
class DailyHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dayKey => text()();
  TextColumn get title => text()();
  DateTimeColumn get shownAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{dayKey, title}];
}
/// 工程速查掌握状态（用户数据）：0 未看 / 1 看过 / 2 掌握。
class QuickRefProgress extends Table {
  TextColumn get refId => text()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get seenCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {refId};
}
/// 章节学习状态：0 未学 / 1 看过 / 2 掌握；bestScore 为自测最好成绩。
class ChapterLearningProgress extends Table {
  TextColumn get chapterKey => text()();
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get bestScore => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {chapterKey};
}
