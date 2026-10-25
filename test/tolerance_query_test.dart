import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/core/errors/exceptions.dart';
import 'package:tolerance_tool/data/database/app_database.dart';
import 'package:tolerance_tool/data/database/seed/seed_files.dart';
import 'package:tolerance_tool/data/database/seed/seed_importer.dart';
import 'package:tolerance_tool/data/repositories/drift_repositories.dart';
import 'package:tolerance_tool/domain/models/standard_context.dart';
import 'package:tolerance_tool/domain/models/tolerance_models.dart';
import 'package:tolerance_tool/domain/parsing/designation_parser.dart';
import 'package:tolerance_tool/domain/services/knowledge_service.dart';
import 'package:tolerance_tool/domain/services/tolerance_query_service.dart';

/// 用真实种子 JSON（assets/data）在内存库中验证查询闭环。
/// 期望值来自占位数据集本身——数值须由工程师按标准原文核对后替换。
void main() {
  late AppDatabase db;
  late ToleranceQueryService service;
  late KnowledgeService knowledge;
  const ctx = StandardContext(
    family: 'ISO',
    primaryStandard: 'ISO_286',
    fallbackChain: ['ISO_286'],
  );

  setUpAll(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final files = <String, String>{};
    for (final name in kSeedFiles) {
      files[name] = File('assets/data/$name').readAsStringSync();
    }
    await SeedImporter(db).seedIfNeeded(files);
    service = ToleranceQueryService(DriftToleranceRepository(db), DriftKnowledgeRepository(db));
    knowledge = KnowledgeService(DriftKnowledgeRepository(db));
  });

  tearDownAll(() async => db.close());

  group('尺寸公差查询（占位数据集期望值）', () {
    test('⌀50 H7/g6 → 间隙配合，Xmax +50 / Xmin +9 μm', () async {
      final r = await service.query(DesignationParser.parse('⌀50 H7/g6'), ctx);
      expect(r.stepBracket, '30~50');
      expect(r.hole.upperUm, 25); // ES = +0.025【占位】
      expect(r.hole.lowerUm, 0); // EI = 0
      expect(r.shaft!.upperUm, -9); // es = −0.009【占位】
      expect(r.shaft!.lowerUm, -25); // ei = −0.025【占位】
      expect(r.fitType, FitType.clearance);
      expect(r.xMaxUm, 50);
      expect(r.xMinUm, 9);
      expect(r.holeBasis, isTrue);
    });

    test('⌀30 H7/k6 → 过渡配合，Xmax +19 / Ymax 15 μm', () async {
      final r = await service.query(DesignationParser.parse('⌀30 H7/k6'), ctx);
      expect(r.hole.upperUm, 21); // IT7(18~30) = 21【占位】
      expect(r.shaft!.upperUm, 15); // es = ei + IT6 = 2 + 13【占位】
      expect(r.shaft!.lowerUm, 2);
      expect(r.fitType, FitType.transition);
      expect(r.xMaxUm, 19);
      expect(r.xMinUm, -15);
      expect(r.fitTerms[1].label, '最大过盈 Ymax');
    });

    test('⌀50 H7/p6 → 过盈配合，Ymax 42 / Ymin 1 μm', () async {
      final r = await service.query(DesignationParser.parse('⌀50 H7/p6'), ctx);
      expect(r.shaft!.upperUm, 42); // es = 26 + 16【占位】
      expect(r.shaft!.lowerUm, 26);
      expect(r.fitType, FitType.interference);
      expect(r.xMaxUm, -1); // 最小过盈 1 μm（ES − ei = 25 − 26）
      expect(r.xMinUm, -42); // 最大过盈 42 μm（EI − es = 0 − 42）
      expect(r.fitTerms[0].um, 42);
      expect(r.fitTerms[1].um, 1);
    });

    test('⌀20 H8/f7 → 间隙配合，Xmax +74 / Xmin +20 μm（18~30 段）', () async {
      final r = await service.query(DesignationParser.parse('⌀20 H8/f7'), ctx);
      expect(r.stepBracket, '18~30');
      expect(r.hole.upperUm, 33); // IT8(18~30) = 33【占位】
      expect(r.shaft!.upperUm, -20);
      expect(r.shaft!.lowerUm, -41); // −20 − 21【占位】
      expect(r.fitType, FitType.clearance);
      expect(r.xMaxUm, 74);
      expect(r.xMinUm, 20);
    });

    test('⌀50 H7（仅孔）→ 无配合结果', () async {
      final r = await service.query(DesignationParser.parse('⌀50 H7'), ctx);
      expect(r.shaft, isNull);
      expect(r.fitType, isNull);
      expect(r.xMaxUm, isNull);
    });

    test('⌀50 H7/u6 → 过盈配合（扩展数据集 r/u）', () async {
      final r = await service.query(DesignationParser.parse('⌀50 H7/u6'), ctx);
      expect(r.shaft!.lowerUm, 70); // u ei(40~50 段值)【占位待核对】
      expect(r.shaft!.upperUm, 86); // es = 70 + 16
      expect(r.fitType, FitType.interference);
      expect(r.xMaxUm, -45); // 最小过盈 45 μm
      expect(r.xMinUm, -86); // 最大过盈 86 μm
    });

    test('⌀130 R7/h6 → 孔系 R 子段按镜像 + Δ 计算', () async {
      final r = await service.query(DesignationParser.parse('⌀130 R7/h6'), ctx);
      // R 基准 ES=-63，R7 加 Δ=IT7-IT6=15 → -48；EI=-48-40=-88。
      expect(r.hole.upperUm, -48);
      expect(r.hole.lowerUm, -88);
    });

    test('⌀130 H7/r6 → r 使用 120~140 子段 +63 μm', () async {
      final r = await service.query(DesignationParser.parse('⌀130 H7/r6'), ctx);
      expect(r.stepBracket, '120~180');
      expect(r.shaft!.lowerUm, 63);
      expect(r.shaft!.upperUm, 88); // 63 + IT6(25)
      expect(r.fitType, FitType.interference);
    });

    test('⌀50 K7/N7/P7/S7 → 孔系等级例外按 Δ=IT7−IT6 计算', () async {
      final k = await service.query(DesignationParser.parse('⌀50 K7'), ctx);
      expect(k.hole.upperUm, 7);
      expect(k.hole.lowerUm, -18);

      final n = await service.query(DesignationParser.parse('⌀50 N7'), ctx);
      expect(n.hole.upperUm, -8);
      expect(n.hole.lowerUm, -33);

      final p7 = await service.query(DesignationParser.parse('⌀50 P7'), ctx);
      expect(p7.hole.upperUm, -17);
      expect(p7.hole.lowerUm, -42);

      final s = await service.query(DesignationParser.parse('⌀50 S7'), ctx);
      expect(s.hole.upperUm, -34);
      expect(s.hole.lowerUm, -59);
    });

    test('未收录代号（z）不编造数值，明确报错', () async {
      await expectLater(
        service.query(DesignationParser.parse('⌀50 H7/z6'), ctx),
        throwsA(isA<DataNotSeedException>()),
      );
    });

    test('超范围尺寸明确报错', () {
      expect(
        () => service.query(DesignationParser.parse('⌀600 H7/g6'), ctx),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('知识提示（全部来自 knowledge_relations / explanation_cards）', () {
    test('⌀50 H7/g6 提示包含默认公差原则（独立原则）', () async {
      final r = await service.query(DesignationParser.parse('⌀50 H7/g6'), ctx);
      final tips = await knowledge.tipsFor(r, ctx);
      final principle = tips.firstWhere((t) => t.title == '当前标准默认公差原则');
      expect(principle.text, contains('独立原则'));
      expect(principle.text, contains('ISO 286'));
      expect(principle.trace, startsWith('knowledge_relations #'));
    });

    test('提示包含配合性质卡与基孔制卡', () async {
      final r = await service.query(DesignationParser.parse('⌀50 H7/g6'), ctx);
      final tips = await knowledge.tipsFor(r, ctx);
      expect(tips.any((t) => t.title.contains('间隙配合')), isTrue);
      expect(tips.any((t) => t.title.contains('基孔制')), isTrue);
      expect(tips.any((t) => t.title.contains('H7')), isTrue);
    });
  });

  group('种子导入幂等与校验', () {
    test('重复导入不重复写库（按 checksum 跳过）', () async {
      final files = <String, String>{};
      for (final name in kSeedFiles) {
        files[name] = File('assets/data/$name').readAsStringSync();
      }
      final before = await (db.select(db.itToleranceValues)
            ..where((t) => t.standardCode.equals('ISO_286')))
          .get();
      await SeedImporter(db).seedIfNeeded(files); // 第二次导入
      final after = await (db.select(db.itToleranceValues)
            ..where((t) => t.standardCode.equals('ISO_286')))
          .get();
      expect(after.length, before.length);
      expect(after.length, 234);
    });

    test('标准值已核对：IT 公差表行 verified = true', () async {
      final unverified = await (db.select(db.itToleranceValues)
            ..where((t) => t.verified.equals(false)))
          .get();
      final all = await db.select(db.itToleranceValues).get();
      expect(all, isNotEmpty);
      expect(unverified, isEmpty);
    });
  });
}