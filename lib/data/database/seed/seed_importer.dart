import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../app_database.dart';

/// Seed importer: transactionally imports assets/data JSON into SQLite.
/// Idempotent: skips when seed_meta version + checksum are unchanged.
/// Validates referential integrity (steps/grades/devs/standards must exist).
class SeedImporter {
  SeedImporter(this._db);

  final AppDatabase _db;

  static const seedVersion = '0.1.0';
  static const datasetName = 'seed_pack';

  Future<void> seedIfNeeded(Map<String, String> files) async {
    final buf = StringBuffer();
    for (final key in files.keys.toList()..sort()) {
      buf
        ..write(key)
        ..write('=')
        ..write(files[key])
        ..write('\n');
    }
    final checksum = md5.convert(utf8.encode(buf.toString())).toString();

    final existing = await (_db.select(_db.seedMeta)
          ..where((t) => t.datasetName.equals(datasetName)))
        .getSingleOrNull();
    if (existing != null && existing.version == seedVersion && existing.checksum == checksum) {
      return;
    }

    // app_settings 是用户数据：先记下现有值，导入完再覆盖回默认值之上。
    // 否则每次加/改种子数据都会把主题、字号、置顶工具重置。
    final savedSettings = await (_db.select(_db.appSettings)).get();

    await _db.transaction(() async {
      // 用户数据表不随种子导入清库（书签/进度/已读/收藏/查询历史保留）。
      const userTables = {
        'reading_progress',
        'bookmarks',
        'chapter_read_marks',
        'favorites',
        'query_history',
        'vocab_progress',
        'daily_history',
        'quick_ref_progress',
        'chapter_learning_progress'
      };
      for (final table in _db.allTables) {
        if (userTables.contains(table.actualTableName)) continue;
        await _db.delete(table).go();
      }
      // design_tips 中用户自定义导入的条目同样保留（仅替换系统条目）。
      await (_db.delete(_db.designTips)..where((t) => t.isCustom.equals(false))).go();
      await _insertAll(files);
      // 恢复用户设置（不覆盖新版本的默认键，只覆盖用户实际改过的键）。
      for (final s in savedSettings) {
        await _db.into(_db.appSettings).insertOnConflictUpdate(
              AppSettingsCompanion.insert(key: s.key, value: s.value),
            );
      }
      await _db.into(_db.seedMeta).insert(SeedMetaCompanion.insert(
            datasetName: datasetName,
            version: seedVersion,
            checksum: checksum,
          ));
    });
  }

  // ---------- parsing ----------

  List<Map<String, dynamic>> _rows(Map<String, String> files, String fileName) {
    final raw = files[fileName];
    if (raw == null) throw StateError('Missing seed file: $fileName');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final columns = (decoded['columns'] as List).cast<String>();
    final rows = decoded['rows'] as List;
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final cells = row as List;
      if (cells.length != columns.length) {
        throw StateError('$fileName has a row with wrong column count');
      }
      final map = <String, dynamic>{};
      for (var i = 0; i < columns.length; i++) {
        map[columns[i]] = cells[i];
      }
      out.add(map);
    }
    return out;
  }

  String _s(Map<String, dynamic> r, String k) => r[k] as String;
  int _i(Map<String, dynamic> r, String k) => (r[k] as num).round();
  double _d(Map<String, dynamic> r, String k) => (r[k] as num).toDouble();
  bool _b(Map<String, dynamic> r, String k) => (r[k] as bool?) ?? false;
  String? _sn(Map<String, dynamic> r, String k) => r[k] as String?;
  int? _in(Map<String, dynamic> r, String k) => r[k] as int?;

  // ---------- validation + write ----------

  Future<void> _insertAll(Map<String, String> files) async {
    final standards = _rows(files, 'standards.json');
    final familyMap = _rows(files, 'standard_family_map.json');
    final steps = _rows(files, 'size_steps.json');
    final grades = _rows(files, 'it_grades.json');
    final devs = _rows(files, 'fundamental_deviations.json');
    final gdntItems = _rows(files, 'gdnt_items.json');
    final principles = _rows(files, 'tolerance_principles.json');
    final itValues = _rows(files, 'it_tolerance_values.json');
    final devValues = _rows(files, 'fundamental_deviation_values.json');
    final gdntGrades = _rows(files, 'gdnt_grade_values.json');
    final preferred = _rows(files, 'preferred_fits.json');
    final general = _rows(files, 'general_tolerances.json');
    final overrides = _rows(files, 'fundamental_deviation_overrides.json');
    final equivalences = _rows(files, 'value_equivalences.json');
    final relations = _rows(files, 'knowledge_relations.json');
    final cards = _rows(files, 'explanation_cards.json');
    final rules = _rows(files, 'fit_recommendation_rules.json');
    final settings = _rows(files, 'app_settings.json');
    final vocab = _rows(files, 'vocab_words.json');
    final dailyFacts = _rows(files, 'daily_facts.json');
    final quickRef = _rows(files, 'quick_ref_items.json');
    final designTips = _rows(files, 'design_tips.json');

    // referential integrity checks
    final standardIds = standards.map((r) => _s(r, 'standard_code')).toSet();
    final stepIds = steps.map((r) => _s(r, 'step_id')).toSet();
    final gradeIds = grades.map((r) => _s(r, 'grade_id')).toSet();
    final devIds = devs.map((r) => _s(r, 'dev_id')).toSet();
    final itemIds = gdntItems.map((r) => _s(r, 'item_id')).toSet();
    final cardKeys = cards.map((r) => _s(r, 'card_key')).toSet();

    void require(bool cond, String message) {
      if (!cond) throw StateError('Seed validation failed: $message');
    }

    for (final r in itValues) {
      require(standardIds.contains(_s(r, 'standard_code')),
          'it_tolerance_values references unknown standard ${_s(r, 'standard_code')}');
      require(stepIds.contains(_s(r, 'step_id')),
          'it_tolerance_values references unknown step ${_s(r, 'step_id')}');
      require(gradeIds.contains(_s(r, 'grade_id')),
          'it_tolerance_values references unknown grade ${_s(r, 'grade_id')}');
    }
    for (final r in devValues) {
      require(standardIds.contains(_s(r, 'standard_code')),
          'fundamental_deviation_values references unknown standard ${_s(r, 'standard_code')}');
      require(stepIds.contains(_s(r, 'step_id')),
          'fundamental_deviation_values references unknown step ${_s(r, 'step_id')}');
      require(devIds.contains(_s(r, 'dev_id')),
          'fundamental_deviation_values references unknown deviation ${_s(r, 'dev_id')}');
    }
    for (final r in general) {
      require(stepIds.contains(_s(r, 'step_id')),
          'general_tolerances references unknown step ${_s(r, 'step_id')}');
    }
    for (final r in gdntGrades) {
      require(standardIds.contains(_s(r, 'standard_code')),
          'gdnt_grade_values references unknown standard ${_s(r, 'standard_code')}');
      require(itemIds.contains(_s(r, 'item_id')),
          'gdnt_grade_values references unknown item ${_s(r, 'item_id')}');
    }
    for (final r in relations) {
      if (_s(r, 'relation_type') == 'EXPLANATION_CARD' && _sn(r, 'object_ref') != null) {
        final key = _s(r, 'object_ref');
        require(!key.startsWith('card:') || cardKeys.contains(key.substring(5)),
            'knowledge_relations references unknown card $key');
      }
    }

    await _db.batch((b) {
      b.insertAll(_db.standards, [
        for (final r in standards)
          StandardsCompanion(
            standardCode: Value(_s(r, 'standard_code')),
            displayName: Value(_s(r, 'display_name')),
            family: Value(_s(r, 'family')),
            domain: Value(_s(r, 'domain')),
            fallbackStandardCode: Value(_sn(r, 'fallback_standard_code')),
            dataStatus: Value(_s(r, 'data_status')),
            sourceNote: Value(_sn(r, 'source_note')),
          ),
      ]);
      b.insertAll(_db.standardFamilyMap, [
        for (final r in familyMap)
          StandardFamilyMapCompanion(
            family: Value(_s(r, 'family')),
            domain: Value(_s(r, 'domain')),
            primaryStandard: Value(_s(r, 'primary_standard')),
            fallbackChain: Value(_s(r, 'fallback_chain')),
            switchNote: Value(_sn(r, 'switch_note')),
          ),
      ]);
      b.insertAll(_db.sizeSteps, [
        for (final r in steps)
          SizeStepsCompanion(
            stepId: Value(_s(r, 'step_id')),
            lowerMm: Value(_d(r, 'lower_mm')),
            upperMm: Value(_d(r, 'upper_mm')),
            bracket: Value(_s(r, 'bracket')),
            scope: Value(_sn(r, 'scope')),
            sort: Value(_i(r, 'sort')),
          ),
      ]);
      b.insertAll(_db.itGrades, [
        for (final r in grades)
          ItGradesCompanion(
            gradeId: Value(_s(r, 'grade_id')),
            sort: Value(_i(r, 'sort')),
            note: Value(_sn(r, 'note')),
          ),
      ]);
      b.insertAll(_db.fundamentalDeviations, [
        for (final r in devs)
          FundamentalDeviationsCompanion(
            devId: Value(_s(r, 'dev_id')),
            appliesTo: Value(_s(r, 'applies_to')),
            zoneClass: Value(_s(r, 'zone_class')),
            formulaNote: Value(_sn(r, 'formula_note')),
          ),
      ]);
      b.insertAll(_db.gdntItems, [
        for (final r in gdntItems)
          GdntItemsCompanion(
            itemId: Value(_s(r, 'item_id')),
            symbol: Value(_s(r, 'symbol')),
            name: Value(_s(r, 'name')),
            category: Value(_s(r, 'category')),
            requiresDatum: Value(_b(r, 'requires_datum')),
            zoneShape: Value(_s(r, 'zone_shape')),
            featureType: Value(_s(r, 'feature_type')),
            availability: Value(_s(r, 'availability')),
          ),
      ]);
      b.insertAll(_db.tolerancePrinciples, [
        for (final r in principles)
          TolerancePrinciplesCompanion(
            principleId: Value(_s(r, 'principle_id')),
            name: Value(_s(r, 'name')),
            shortSymbol: Value(_sn(r, 'short_symbol')),
            definitionRef: Value(_sn(r, 'definition_ref')),
          ),
      ]);
      b.insertAll(_db.itToleranceValues, [
        for (final r in itValues)
          ItToleranceValuesCompanion(
            standardCode: Value(_s(r, 'standard_code')),
            stepId: Value(_s(r, 'step_id')),
            gradeId: Value(_s(r, 'grade_id')),
            valueUm: Value(_i(r, 'value_um')),
            sourceRef: Value(_s(r, 'source_ref')),
            verified: Value(_b(r, 'verified')),
          ),
      ]);
      b.insertAll(_db.fundamentalDeviationValues, [
        for (final r in devValues)
          FundamentalDeviationValuesCompanion(
            standardCode: Value(_s(r, 'standard_code')),
            stepId: Value(_s(r, 'step_id')),
            devId: Value(_s(r, 'dev_id')),
            definedSide: Value(_s(r, 'defined_side')),
            deviationUm: Value(_i(r, 'deviation_um')),
            oppositeUm: Value(_in(r, 'opposite_um')),
            sourceRef: Value(_s(r, 'source_ref')),
            verified: Value(_b(r, 'verified')),
          ),
      ]);
      b.insertAll(_db.fundamentalDeviationOverrides, [
        for (final r in overrides)
          FundamentalDeviationOverridesCompanion(
            standardCode: Value(_s(r, 'standard_code')),
            devId: Value(_s(r, 'dev_id')),
            lowerMm: Value(_d(r, 'lower_mm')),
            upperMm: Value(_d(r, 'upper_mm')),
            definedSide: Value(_s(r, 'defined_side')),
            deviationUm: Value(_i(r, 'deviation_um')),
            sourceRef: Value(_s(r, 'source_ref')),
            verified: Value(_b(r, 'verified')),
          ),
      ]);
      b.insertAll(_db.gdntGradeValues, [
        for (final r in gdntGrades)
          GdntGradeValuesCompanion(
            standardCode: Value(_s(r, 'standard_code')),
            itemId: Value(_s(r, 'item_id')),
            gradeIndex: Value(_i(r, 'grade_index')),
            stepId: Value(_s(r, 'step_id')),
            valueMm: Value(_d(r, 'value_mm')),
            sourceRef: Value(_s(r, 'source_ref')),
            verified: Value(_b(r, 'verified')),
          ),
      ]);
      b.insertAll(_db.preferredFits, [
        for (final r in preferred)
          PreferredFitsCompanion(
            standardCode: Value(_s(r, 'standard_code')),
            system: Value(_s(r, 'system')),
            fitType: Value(_s(r, 'fit_type')),
            holeDev: Value(_s(r, 'hole_dev')),
            holeGrade: Value(_i(r, 'hole_grade')),
            shaftDev: Value(_s(r, 'shaft_dev')),
            shaftGrade: Value(_i(r, 'shaft_grade')),
            usageTag: Value(_s(r, 'usage_tag')),
            usageNote: Value(_sn(r, 'usage_note')),
          ),
      ]);
      b.insertAll(_db.generalTolerances, [
        for (final r in general)
          GeneralTolerancesCompanion(
            standardCode: Value(_s(r, 'standard_code')),
            classCode: Value(_s(r, 'class_code')),
            kind: Value(_s(r, 'kind')),
            stepId: Value(_s(r, 'step_id')),
            value: Value(_d(r, 'value')),
            unit: Value(_s(r, 'unit')),
            sourceRef: Value(_s(r, 'source_ref')),
            verified: Value(_b(r, 'verified')),
          ),
      ]);
      b.insertAll(_db.valueEquivalences, [
        for (final r in equivalences)
          ValueEquivalencesCompanion(
            equivId: Value(_s(r, 'equiv_id')),
            sourceStandard: Value(_s(r, 'source_standard')),
            targetStandard: Value(_s(r, 'target_standard')),
            direction: Value(_s(r, 'direction')),
            appliesTo: Value(_s(r, 'applies_to')),
            mapping: Value(_s(r, 'mapping')),
            statement: Value(_s(r, 'statement')),
            note: Value(_sn(r, 'note')),
          ),
      ]);
      b.insertAll(_db.knowledgeRelations, [
        for (final r in relations)
          KnowledgeRelationsCompanion(
            relationType: Value(_s(r, 'relation_type')),
            subjectRef: Value(_s(r, 'subject_ref')),
            objectRef: Value(_sn(r, 'object_ref')),
            scopeStandard: Value(_sn(r, 'scope_standard')),
            predicate: Value(_s(r, 'predicate')),
            payload: Value(_s(r, 'payload')),
            statement: Value(_s(r, 'statement')),
            severity: Value(_sn(r, 'severity')),
            sourceRef: Value(_sn(r, 'source_ref')),
            enabled: Value(_b(r, 'enabled')),
            priority: Value(_i(r, 'priority')),
          ),
      ]);
      b.insertAll(_db.explanationCards, [
        for (final r in cards)
          ExplanationCardsCompanion(
            cardKey: Value(_s(r, 'card_key')),
            title: Value(_s(r, 'title')),
            definitionMd: Value(_s(r, 'definition_md')),
            engineeringMd: Value(_s(r, 'engineering_md')),
            standardDiffMd: Value(_sn(r, 'standard_diff_md')),
            relatedRefs: Value(_s(r, 'related_refs')),
            tags: Value(_s(r, 'tags')),
            sourceRef: Value(_sn(r, 'source_ref')),
          ),
      ]);
      b.insertAll(_db.fitRecommendationRules, [
        for (final r in rules)
          FitRecommendationRulesCompanion(
            ruleId: Value(_s(r, 'rule_id')),
            scopeStandard: Value(_sn(r, 'scope_standard')),
            system: Value(_s(r, 'system')),
            fitType: Value(_s(r, 'fit_type')),
            gradePool: Value(_s(r, 'grade_pool')),
            preferredOnly: Value(_b(r, 'preferred_only')),
            scoring: Value(_s(r, 'scoring')),
            costHints: Value(_s(r, 'cost_hints')),
            candidateLimit: Value(_i(r, 'candidate_limit')),
            reasonTemplates: Value(_s(r, 'reason_templates')),
            sourceRef: Value(_sn(r, 'source_ref')),
            enabled: Value(_b(r, 'enabled')),
          ),
      ]);
      b.insertAll(_db.appSettings, [
        for (final r in settings)
          AppSettingsCompanion(
            key: Value(_s(r, 'key')),
            value: Value(_s(r, 'value')),
          ),
      ]);
      b.insertAll(_db.vocabWords, [
        for (final r in vocab)
          VocabWordsCompanion(
            en: Value(_s(r, 'en')),
            zh: Value(_s(r, 'zh')),
            category: Value(_s(r, 'category')),
            example: Value(_sn(r, 'example')),
          ),
      ]);
      b.insertAll(_db.dailyFacts, [
        for (final r in dailyFacts)
          DailyFactsCompanion(
            title: Value(_s(r, 'title')),
            body: Value(_s(r, 'body')),
            chapterKey: Value(_s(r, 'chapter_key')),
            anchor: Value(_sn(r, 'anchor')),
            source: Value(_sn(r, 'source')),
          ),
      ]);
      b.insertAll(_db.quickRefItems, [
        for (final r in quickRef)
          QuickRefItemsCompanion(
            refId: Value(_s(r, 'ref_id')),
            category: Value(_s(r, 'category')),
            title: Value(_s(r, 'title')),
            contentMd: Value(_s(r, 'content_md')),
            keywords: Value(_s(r, 'keywords')),
            tip: Value(_s(r, 'tip')),
            sourceRef: Value(_sn(r, 'source_ref')),
          ),
      ]);
      b.insertAll(_db.designTips, [
        for (final r in designTips)
          DesignTipsCompanion(
            title: Value(_s(r, 'title')),
            body: Value(_s(r, 'body')),
            category: Value(_s(r, 'category')),
            chapterKey: Value(_sn(r, 'chapter_key')),
            anchor: Value(_sn(r, 'anchor')),
            isCustom: const Value(false),
          ),
      ]);
    });

    // 词库与速查的 FTS 索引随种子重建（trigram 分词，支持中文子串双向检索）。
    await _db.rebuildVocabFts();
    await _db.rebuildQuickRefFts();
  }
}