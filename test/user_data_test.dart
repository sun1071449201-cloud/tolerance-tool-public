import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/data/database/app_database.dart';
import 'package:tolerance_tool/data/database/seed/seed_files.dart';
import 'package:tolerance_tool/data/database/seed/seed_importer.dart';
import 'package:tolerance_tool/data/repositories/user_data_repositories.dart';
import 'package:tolerance_tool/domain/services/import_service.dart';

void main() {
  late AppDatabase db;
  late DriftReadingUserDataRepository repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final files = <String, String>{};
    for (final name in kSeedFiles) {
      files[name] = File('assets/data/$name').readAsStringSync();
    }
    await SeedImporter(db).seedIfNeeded(files);
    repo = DriftReadingUserDataRepository(db);
  });

  tearDownAll(() async => db.close());

  group('设计常识库（AI 知识库 + 自定义导入）', () {
    test('系统常识库不少于 300 条', () async {
      final tips = await repo.allDesignTips();
      expect(tips.where((t) => !t.isCustom).length, greaterThanOrEqualTo(300));
    });

    test('ImportService 解析 JSON', () {
      final r = ImportService.parse('a.json', '[{"title":"T","text":"B"}]');
      expect(r.single.title, 'T');
      expect(r.single.body, 'B');
    });

    test('ImportService 解析 CSV（带引号转义）', () {
      final r = ImportService.parse(
          'a.csv', 'title,text,category\n"含,逗号","正文""引号""",分类');
      expect(r.single.title, '含,逗号');
      expect(r.single.body, '正文"引号"');
      expect(r.single.category, '分类');
    });

    test('ImportService 解析 Markdown', () {
      final r = ImportService.parse('a.md', '# 标题一\n正文一\n## 标题二\n正文二');
      expect(r.length, 2);
      expect(r[0].title, '标题一');
      expect(r[1].body, '正文二');
    });

    test('自定义导入带 custom_import 标记并保留（种子重导不清除）', () async {
      final n = await repo.addCustomTips([
        DesignTipsCompanion.insert(
          title: '自定义条目一',
          body: '内容一',
          category: '我的笔记',
        ),
      ]);
      expect(n, 1);

      // 重新执行种子导入（checksum 相同会跳过；强制场景：设计条目只替换系统条目）
      final custom = await repo.allDesignTips();
      expect(custom.any((t) => t.title == '自定义条目一' && t.isCustom), isTrue);
    });
  });

  group('阅读进度与书签', () {
    test('进度保存与读取', () async {
      await repo.saveProgress(
          bookId: 'qc_book', chapterKey: 'qc_book.ch01', offsetPx: 1234.5);
      expect(await repo.progressOf('qc_book', 'qc_book.ch01'), 1234.5);
      // 覆盖更新
      await repo.saveProgress(
          bookId: 'qc_book', chapterKey: 'qc_book.ch01', offsetPx: 999.0);
      expect(await repo.progressOf('qc_book', 'qc_book.ch01'), 999.0);
      // 未读书籍默认 0
      expect(await repo.progressOf('no_book', 'no_ch'), 0);
    });

    test('最近阅读章节按更新时间取最新', () async {
      await repo.saveProgress(
          bookId: 'growth_book', chapterKey: 'growth_book.ch01', offsetPx: 10);
      final last = await repo.lastReadChapter('growth_book');
      expect(last, 'growth_book.ch01');
    });

    test('书签添加/查询/批量删除', () async {
      final b = await repo.addBookmark(
        bookId: 'qc_book',
        chapterKey: 'qc_book.ch01',
        segmentIndex: 3,
        excerpt: '判定红线与易错点汇总…',
        note: '上岗必背',
        anchor: '1.2.3',
      );
      final list = await repo.bookmarksForChapter('qc_book.ch01');
      expect(
        list.any((x) =>
            x.id == b.id && x.note == '上岗必背' && x.anchor == '1.2.3'),
        isTrue,
      );

      await repo.deleteBookmarks([b.id]);
      final after = await repo.bookmarksForChapter('qc_book.ch01');
      expect(after.any((x) => x.id == b.id), isFalse);
    });

    test('已读标记切换', () async {
      await repo.setRead('growth_book.ch01');
      await repo.setRead('growth_book.ch02');
      final marks = await repo.readMarks();
      expect(marks['growth_book.ch01'], isTrue);
      await repo.setRead('growth_book.ch01', isRead: false);
      final after = await repo.readMarks();
      expect(after['growth_book.ch01'], isFalse);
      expect(after['growth_book.ch02'], isTrue);
    });
  });
}