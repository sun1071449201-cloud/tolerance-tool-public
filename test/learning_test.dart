import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/data/database/app_database.dart';
import 'package:tolerance_tool/data/database/seed/seed_files.dart';
import 'package:tolerance_tool/data/database/seed/seed_importer.dart';
import 'package:tolerance_tool/data/repositories/drift_repositories.dart';
import 'package:tolerance_tool/data/repositories/learning_repositories.dart';
import 'package:tolerance_tool/data/repositories/user_data_repositories.dart';
import 'package:tolerance_tool/domain/services/daily_service.dart';

/// 学习模块综合测试：词库 FTS 双向检索、每日知识点池、第 4 本书。
void main() {
  late AppDatabase db;
  late DriftVocabRepository vocab;
  late DriftDailyFactsRepository facts;
  late DriftKnowledgeRepository knowledge;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final files = <String, String>{};
    for (final name in kSeedFiles) {
      files[name] = File('assets/data/$name').readAsStringSync();
    }
    await SeedImporter(db).seedIfNeeded(files);
    vocab = DriftVocabRepository(db);
    facts = DriftDailyFactsRepository(db);
    knowledge = DriftKnowledgeRepository(db);
  });

  tearDownAll(() async => db.close());

  group('机械英语词库（FTS 双向检索）', () {
    test('词库不少于 200 条', () async {
      expect((await vocab.all()).length, greaterThanOrEqualTo(200));
    });

    test('英文检索：bearing 命中轴承', () async {
      final r = await vocab.search('bearing');
      expect(r, isNotEmpty);
      expect(r.any((w) => w.zh.contains('轴承')), isTrue);
    });

    test('中文检索：轴承 命中英文', () async {
      final r = await vocab.search('轴承');
      expect(r, isNotEmpty);
      expect(r.any((w) => w.en.toLowerCase().contains('bearing')), isTrue);
    });

    test('中文短词（2 字）LIKE 兜底可检索', () async {
      final r = await vocab.search('公差');
      expect(r.length, greaterThanOrEqualTo(3));
    });

    test('无匹配返回空列表', () async {
      expect(await vocab.search('zzzzqqqq'), isEmpty);
    });

    test('背诵进度：已背/还不熟可持久化', () async {
      await vocab.markWord(1, known: true);
      var map = await vocab.progressMap();
      expect(map[1], 2);
      await vocab.markWord(1, known: false);
      map = await vocab.progressMap();
      expect(map[1], 1);
      await vocab.markSeen(1);
      expect((await vocab.progressMap())[1], 1);
    });
  });

  group('工程速查与选型（FTS + 经验卡）', () {
    test('速查条目不少于 40 条且分 4 类', () async {
      final repo = DriftQuickRefRepository(db);
      final all = await repo.all();
      expect(all.length, greaterThanOrEqualTo(40));
      final cats = all.map((e) => e.category).toSet();
      expect(cats.length, 4);
      // 表面处理补充后至少 15 条，且电解抛光条目仍在。
      expect(
        all.where((e) => e.category == '表面处理').length,
        greaterThanOrEqualTo(15),
      );
      expect(all.any((e) => e.refId == 'qr_sf_ep'), isTrue);
    });

    test('中文检索：M6 命中底孔速查并带经验卡', () async {
      final repo = DriftQuickRefRepository(db);
      final r = await repo.search('M6');
      expect(r, isNotEmpty);
      final tap = r.where((e) => e.refId == 'qr_std_tapdrill').toList();
      expect(tap, isNotEmpty);
      expect(tap.first.tip, contains('底孔'));
      expect(tap.first.contentMd, contains('Ø5.0'));
    });

    test('短词检索：锌 命中镀锌条目', () async {
      final repo = DriftQuickRefRepository(db);
      final r = await repo.search('锌');
      expect(r.any((e) => e.refId == 'qr_sf_zinc'), isTrue);
    });
  });

  group('每日知识点', () {
    test('推荐池不少于 50 条（daily_facts + 关系表合并）', () async {
      // 通过池大小间接验证：todays 取 3 条，池不足 3 也会是 3；
      // 直接验证 facts 表 + EXPLANATION_CARD 关系数量。
      expect((await facts.all()).length, greaterThanOrEqualTo(50));      expect(
          (await knowledge.relationsByType('EXPLANATION_CARD')).length,
          greaterThanOrEqualTo(8));
    });

    test('每天抽 3 条且同一天结果稳定', () async {
      final svc = DailyService(facts, knowledge, DriftQuickRefRepository(db), DriftReadingUserDataRepository(db));
      final a = await svc.todays(DateTime(2026, 10, 24));
      final b = await svc.todays(DateTime(2026, 10, 24));
      expect(a.length, 3);
      expect(b.map((t) => t.title).toList(), a.map((t) => t.title).toList());
    });

    test('跨天结果变化且全部可跳转书籍', () async {
      final svc = DailyService(facts, knowledge, DriftQuickRefRepository(db), DriftReadingUserDataRepository(db));
      final d1 = await svc.todays(DateTime(2026, 10, 24));
      final d2 = await svc.todays(DateTime(2026, 10, 25));
      expect(
        d1.map((t) => t.title).join('|'),
        isNot(d2.map((t) => t.title).join('|')),
      );
      for (final t in d1) {
        // 每条必须有内容可展示；可跳转的（书籍章节或速查条目）带定位信息
        expect(t.title, isNotEmpty);
        expect(t.text, isNotEmpty);
        expect(
          t.chapterKey.isNotEmpty || (t.quickRefId?.isNotEmpty ?? false),
          t.sourceLabel != '系统知识' || t.chapterKey.isNotEmpty,
        );
      }
    });
  });
}