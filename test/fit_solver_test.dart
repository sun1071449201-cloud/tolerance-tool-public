import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/data/database/app_database.dart';
import 'package:tolerance_tool/data/database/seed/seed_files.dart';
import 'package:tolerance_tool/data/database/seed/seed_importer.dart';
import 'package:tolerance_tool/data/repositories/drift_repositories.dart';
import 'package:tolerance_tool/domain/models/standard_context.dart';
import 'package:tolerance_tool/domain/services/fit_solver_service.dart';

/// 反选求解测试：基于占位数据集的期望行为。
void main() {
  late AppDatabase db;
  late FitSolverService solver;
  const ctx = StandardContext(
    family: 'ISO',
    primaryStandard: 'ISO_286',
    fallbackChain: ['ISO_286'],
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final files = <String, String>{};
    for (final name in kSeedFiles) {
      files[name] = File('assets/data/$name').readAsStringSync();
    }
    await SeedImporter(db).seedIfNeeded(files);
    solver = FitSolverService(
        DriftToleranceRepository(db), DriftKnowledgeRepository(db), db);
  });

  tearDownAll(() async => db.close());

  group('反选求解（占位数据集）', () {
    test('⌀50 间隙 9~50μm → H7/g6 排在首位且完全命中', () async {
      final results = await solver.solve(
        nominalSize: 50,
        fitType: 'clearance',
        targetMinUm: 9,
        targetMaxUm: 50,
        ctx: ctx,
      );
      expect(results, isNotEmpty);
      expect(results.first.code, 'H7/g6');
      expect(results.first.xMinUm, 9);
      expect(results.first.xMaxUm, 50);
    });

    test('推荐结果按匹配度降序且理由段可追溯', () async {
      final results = await solver.solve(
        nominalSize: 50,
        fitType: 'clearance',
        targetMinUm: 20,
        targetMaxUm: 100,
        ctx: ctx,
      );
      expect(results, isNotEmpty);
      for (var i = 1; i < results.length; i++) {
        expect(results[i - 1].score,
            greaterThanOrEqualTo(results[i].score));
      }
      final first = results.first;
      expect(first.reasons.length, greaterThanOrEqualTo(4));
      // 每条理由必须带追溯（relation_id / rule_id / 表来源）
      for (final r in first.reasons) {
        expect(r.trace, isNotEmpty);
      }
      expect(
        first.reasons.any((r) => r.kind == 'default_principle'),
        isTrue,
      );
    });

    test('类型不匹配的候选被过滤（间隙请求不出过盈配合）', () async {
      final results = await solver.solve(
        nominalSize: 50,
        fitType: 'clearance',
        targetMinUm: 1,
        targetMaxUm: 200,
        ctx: ctx,
      );
      for (final c in results) {
        expect(c.xMinUm, greaterThanOrEqualTo(0),
            reason: '${c.code} 不应为过盈/过渡');
      }
    });

    test('⌀50 过盈 1~42μm → H7/p6 命中', () async {
      final results = await solver.solve(
        nominalSize: 50,
        fitType: 'interference',
        targetMinUm: 1,
        targetMaxUm: 42,
        ctx: ctx,
      );
      expect(results, isNotEmpty);
      expect(results.first.code, 'H7/p6');
      expect(results.first.xMaxUm, -1); // 最小过盈 1μm
      expect(results.first.xMinUm, -42); // 最大过盈 42μm
    });
  });
}
