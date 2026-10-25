import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/concept_tables.dart';
import 'tables/extra_tables.dart';
import 'tables/knowledge_tables.dart';
import 'tables/meta_tables.dart';
import 'tables/quick_ref_tables.dart';
import 'tables/rule_tables.dart';
import 'tables/user_data_tables.dart';
import 'tables/value_tables.dart';

part 'app_database.g.dart';

/// 三层数据模型（25 张表）：
/// 元数据：Standards / StandardFamilyMap / AppSettings / SeedMeta
/// 概念层：SizeSteps / ItGrades / FundamentalDeviations / GdntItems / TolerancePrinciples
/// 标准值层：ItToleranceValues / FundamentalDeviationValues / GdntGradeValues /
///           PreferredFits / GeneralTolerances / ValueEquivalences
/// 知识层：KnowledgeRelations / ExplanationCards
/// 规则：FitRecommendationRules
/// 学习：VocabWords（FTS 检索）/ DailyFacts（每日知识点）
@DriftDatabase(tables: [
  Standards,
  StandardFamilyMap,
  AppSettings,
  SeedMeta,
  SizeSteps,
  ItGrades,
  FundamentalDeviations,
  GdntItems,
  TolerancePrinciples,
  ItToleranceValues,
  FundamentalDeviationValues,
  GdntGradeValues,
  PreferredFits,
  GeneralTolerances,
  ValueEquivalences,
  KnowledgeRelations,
  ExplanationCards,
  FitRecommendationRules,
  VocabWords,
  DailyFacts,
  QuickRefItems,
  ReadingProgress,
  Bookmarks,
  ChapterReadMarks,
  DesignTips,
  Favorites,
  QueryHistory,
  VocabProgress,
  DailyHistory,
  FundamentalDeviationOverrides,
  QuickRefProgress,
  ChapterLearningProgress,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 14;

  /// FTS5 全文索引（trigram 分词支持中文子串匹配）。
  /// 词库表在每次种子导入后全量重建索引（见 SeedImporter）。
  Future<void> createVocabFts() async {
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS vocab_fts USING fts5(en, zh, tokenize='trigram')",
    );
  }

  Future<void> rebuildVocabFts() async {
    await createVocabFts();
    await customStatement('DELETE FROM vocab_fts');
    await customStatement(
      'INSERT INTO vocab_fts(rowid, en, zh) SELECT id, en, zh FROM vocab_words',
    );
  }

  Future<void> createQuickRefFts() async {
    await customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS quickref_fts USING fts5(title, content, keywords, tokenize='trigram')",
    );
  }

  Future<void> rebuildQuickRefFts() async {
    await createQuickRefFts();
    await customStatement('DELETE FROM quickref_fts');
    await customStatement(
      'INSERT INTO quickref_fts(rowid, title, content, keywords) '
      'SELECT id, title, content_md, keywords FROM quick_ref_items',
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await createVocabFts();
          await createQuickRefFts();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(vocabWords);
            await m.createTable(dailyFacts);
            await createVocabFts();
          }
          if (from < 3) {
            await m.createTable(quickRefItems);
            await createQuickRefFts();
          }
          if (from < 4) {
            await m.createTable(readingProgress);
            await m.createTable(bookmarks);
            await m.createTable(chapterReadMarks);
            await m.createTable(designTips);
          }
          if (from < 5) {
            await m.createTable(favorites);
          }
          if (from < 6) {
            await m.createTable(queryHistory);
          }
          if (from < 7) {
            await m.addColumn(bookmarks, bookmarks.anchor);
          }
          if (from < 8) {
            await m.addColumn(quickRefItems, quickRefItems.sourceRef);
          }
          if (from < 9) {
            await m.createTable(vocabProgress);
          }
          // v9 建表时 Drift 会按“当前表定义”建表，已包含这三列；只有真正停在 v9 的旧库才需要补。
          if (from == 9) {
            await m.addColumn(vocabProgress, vocabProgress.intervalDays);
            await m.addColumn(vocabProgress, vocabProgress.dueAt);
            await m.addColumn(vocabProgress, vocabProgress.lapses);
          }
          if (from < 11) {
            await m.createTable(dailyHistory);
          }
          if (from < 12) {
            await m.createTable(fundamentalDeviationOverrides);
          }
          if (from < 13) {
            await m.createTable(quickRefProgress);
          }
          if (from < 14) {
            await m.createTable(chapterLearningProgress);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'tolerance_tool.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}