import 'package:drift/drift.dart';

import '../../domain/models/knowledge_models.dart';
import '../../domain/models/tolerance_models.dart';
import '../../domain/ports/repositories.dart';
import '../database/app_database.dart';

class DriftToleranceRepository implements ToleranceRepository {
  DriftToleranceRepository(this._db);

  final AppDatabase _db;

  @override
  Future<SizeStepInfo?> findStep(double nominalSize) async {
    final rows = await (_db.select(_db.sizeSteps)
          ..where((t) => t.scope.equals('ISO_MAIN'))
          ..orderBy([(t) => OrderingTerm.asc(t.sort)]))
        .get();
    for (final s in rows) {
      // 标准分段约定：(下限, 上限]，即 3 mm 归入 ≤3 段。
      if (nominalSize > s.lowerMm && nominalSize <= s.upperMm) {
        return SizeStepInfo(
          stepId: s.stepId,
          bracket: s.bracket,
          lowerMm: s.lowerMm,
          upperMm: s.upperMm,
        );
      }
    }
    return null;
  }

  @override
  Future<int?> itValueUm({
    required String standardCode,
    required String stepId,
    required String gradeId,
  }) async {
    final row = await (_db.select(_db.itToleranceValues)
          ..where((t) =>
              t.standardCode.equals(standardCode) &
              t.stepId.equals(stepId) &
              t.gradeId.equals(gradeId)))
        .getSingleOrNull();
    return row?.valueUm;
  }

  @override
  Future<DeviationValue?> deviationOverride({
    required String standardCode,
    required String devId,
    required double nominalSize,
  }) async {
    final rows = await (_db.select(_db.fundamentalDeviationOverrides)
          ..where((t) =>
              t.standardCode.equals(standardCode) &
              t.devId.equals(devId) &
              t.lowerMm.isSmallerThanValue(nominalSize) &
              t.upperMm.isBiggerOrEqualValue(nominalSize)))
        .get();
    if (rows.isEmpty) return null;
    final r = rows.first;
    return DeviationValue(
      definedSide: r.definedSide,
      deviationUm: r.deviationUm,
    );
  }

  @override
  Future<DeviationValue?> deviationValue({
    required String standardCode,
    required String stepId,
    required String devId,
  }) async {
    final row = await (_db.select(_db.fundamentalDeviationValues)
          ..where((t) =>
              t.standardCode.equals(standardCode) &
              t.stepId.equals(stepId) &
              t.devId.equals(devId)))
        .getSingleOrNull();
    if (row == null) return null;
    return DeviationValue(
      definedSide: row.definedSide,
      deviationUm: row.deviationUm,
      oppositeUm: row.oppositeUm,
    );
  }
}

class DriftKnowledgeRepository implements KnowledgeRepository {
  DriftKnowledgeRepository(this._db);

  final AppDatabase _db;

  @override
  Future<RelationRecord?> relationBySubject({
    required String type,
    required String subject,
  }) async {
    final rows = await (_db.select(_db.knowledgeRelations)
          ..where((t) =>
              t.relationType.equals(type) &
              t.subjectRef.equals(subject) &
              t.enabled.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.priority)]))
        .get();
    if (rows.isEmpty) return null;
    final r = rows.first;
    return _toRecord(r);
  }

  @override
  Future<List<RelationRecord>> relationsByType(String type) async {
    final rows = await (_db.select(_db.knowledgeRelations)
          ..where((t) => t.relationType.equals(type) & t.enabled.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.priority)]))
        .get();
    return [for (final r in rows) _toRecord(r)];
  }

  @override
  Future<RelationRecord?> standardEquivalence(String standardA, String standardB) async {
    final sa = 'standard:$standardA';
    final sb = 'standard:$standardB';
    final rows = await (_db.select(_db.knowledgeRelations)
          ..where((t) => t.relationType.equals('STANDARD_EQUIVALENCE') &
              ((t.subjectRef.equals(sa) & t.objectRef.equals(sb)) |
                  (t.subjectRef.equals(sb) & t.objectRef.equals(sa)))))
        .get();
    if (rows.isEmpty) return null;
    return _toRecord(rows.first);
  }

  @override
  Future<CardRecord?> cardByKey(String? cardKey) async {
    if (cardKey == null) return null;
    final row = await (_db.select(_db.explanationCards)
          ..where((t) => t.cardKey.equals(cardKey)))
        .getSingleOrNull();
    if (row == null) return null;
    return CardRecord(
      cardKey: row.cardKey,
      title: row.title,
      definition: row.definitionMd,
      engineering: row.engineeringMd,
      standardDiff: row.standardDiffMd,
    );
  }

  RelationRecord _toRecord(KnowledgeRelation r) => RelationRecord(
        id: r.relationId,
        type: r.relationType,
        subject: r.subjectRef,
        object: r.objectRef,
        predicate: r.predicate,
        payload: r.payload,
        statement: r.statement,
        severity: r.severity,
      );
}