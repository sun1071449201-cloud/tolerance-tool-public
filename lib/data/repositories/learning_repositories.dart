import 'package:drift/drift.dart';

import '../../domain/ports/learning_repository.dart';
import '../database/app_database.dart';

/// 词库检索：FTS5 trigram 全文索引（≥3 字符）+ LIKE 兜底（短词/单字）。
/// en 与 zh 两列同时索引，天然支持中英双向搜索。
class DriftVocabRepository implements VocabRepository {
  DriftVocabRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<VocabWord>> all() async {
    return await (_db.select(_db.vocabWords)
          ..orderBy([
            (t) => OrderingTerm.asc(t.category),
            (t) => OrderingTerm.asc(t.en),
          ]))
        .get();
  }

  @override
  Future<List<VocabWord>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return all();

    // FTS5 trigram 要求查询串至少 3 个字符；短查询退回 LIKE 模糊匹配。
    if (q.runes.length >= 3) {
      final escaped = q.replaceAll("'", "''");
      final rows = await _db.customSelect(
        'SELECT w.id, w.en, w.zh, w.category, w.example '
        'FROM vocab_fts f JOIN vocab_words w ON w.id = f.rowid '
        'WHERE vocab_fts MATCH ? '
        'ORDER BY w.category, w.en LIMIT 100',
        variables: [Variable('"$escaped"')],
      ).get();
      return rows.map(_map).toList();
    }

    final like = '%$q%';
    return await (_db.select(_db.vocabWords)
          ..where((t) => t.en.like(like) | t.zh.like(like))
          ..orderBy([
            (t) => OrderingTerm.asc(t.category),
            (t) => OrderingTerm.asc(t.en),
          ])
          ..limit(100))
        .get();
  }

  @override
  Future<Map<int, int>> progressMap() async {
    final rows = await _db.select(_db.vocabProgress).get();
    return {for (final r in rows) r.wordId: r.status};
  }

  @override
  Future<void> markWord(int wordId, {required bool known}) async {
    final existing = await (_db.select(_db.vocabProgress)
          ..where((t) => t.wordId.equals(wordId)))
        .getSingleOrNull();
    final now = DateTime.now();
    final prevInterval = existing?.intervalDays ?? 0;
    final nextInterval = known
        ? switch (prevInterval) {
            0 => 1,
            1 => 3,
            3 => 7,
            7 => 30,
            _ => 60,
          }
        : 0;
    final status = known ? 2 : 1;
    final dueAt = known ? now.add(Duration(days: nextInterval)) : now;
    if (existing == null) {
      await _db.into(_db.vocabProgress).insert(
            VocabProgressCompanion.insert(
              wordId: Value(wordId),
              status: Value(status),
              seenCount: const Value(1),
              intervalDays: Value(nextInterval),
              dueAt: Value(dueAt),
            ),
          );
    } else {
      await (_db.update(_db.vocabProgress)
            ..where((t) => t.wordId.equals(wordId)))
          .write(VocabProgressCompanion(
        status: Value(status),
        seenCount: Value(existing.seenCount + 1),
        intervalDays: Value(nextInterval),
        dueAt: Value(dueAt),
        lapses: Value(known || existing.status != 2
            ? existing.lapses
            : existing.lapses + 1),
        updatedAt: Value(now),
      ));
    }
  }

  @override
  Future<void> clearWord(int wordId) async {
    await (_db.delete(_db.vocabProgress)
          ..where((t) => t.wordId.equals(wordId)))
        .go();
  }

  @override
  Future<Set<int>> dueWordIds() async {
    final now = DateTime.now();
    final rows = await (_db.select(_db.vocabProgress)
          ..where((t) =>
              t.status.equals(2) &
              t.dueAt.isNotNull() &
              t.dueAt.isSmallerOrEqualValue(now)))
        .get();
    return {for (final r in rows) r.wordId};
  }

  @override
  Future<void> markSeen(int wordId) async {
    final existing = await (_db.select(_db.vocabProgress)
          ..where((t) => t.wordId.equals(wordId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.vocabProgress).insert(
            VocabProgressCompanion.insert(wordId: Value(wordId)),
          );
    } else {
      await (_db.update(_db.vocabProgress)
            ..where((t) => t.wordId.equals(wordId)))
          .write(VocabProgressCompanion(
        seenCount: Value(existing.seenCount + 1),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  VocabWord _map(QueryRow r) => VocabWord(
        id: r.read<int>('id'),
        en: r.read<String>('en'),
        zh: r.read<String>('zh'),
        category: r.read<String>('category'),
        example: r.read<String?>('example'),
      );
}

class DriftDailyFactsRepository implements DailyFactsRepository {
  DriftDailyFactsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<DailyFact>> all() {
    return _db.select(_db.dailyFacts).get();
  }
}

/// 速查检索：FTS5 trigram（≥3 字符）+ LIKE 兜底（短词）。
class DriftQuickRefRepository implements QuickRefRepository {
  DriftQuickRefRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<QuickRefItem>> all() async {
    return await (_db.select(_db.quickRefItems)
          ..orderBy([
            (t) => OrderingTerm.asc(t.category),
            (t) => OrderingTerm.asc(t.title),
          ]))
        .get();
  }

  @override
  Future<List<QuickRefItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return all();

    if (q.runes.length >= 3) {
      final escaped = q.replaceAll("'", "''");
      final rows = await _db.customSelect(
        'SELECT w.id, w.ref_id, w.category, w.title, w.content_md, w.keywords, w.tip, w.source_ref '
        'FROM quickref_fts f JOIN quick_ref_items w ON w.id = f.rowid '
        'WHERE quickref_fts MATCH ? LIMIT 50',
        variables: [Variable('"$escaped"')],
      ).get();
      return rows.map(_map).toList();
    }

    final like = '%$q%';
    return await (_db.select(_db.quickRefItems)
          ..where((t) =>
              t.title.like(like) |
              t.contentMd.like(like) |
              t.keywords.like(like))
          ..orderBy([
            (t) => OrderingTerm.asc(t.category),
            (t) => OrderingTerm.asc(t.title),
          ])
          ..limit(50))
        .get();
  }

  @override
  Future<QuickRefItem?> byRefId(String refId) async {
    return await (_db.select(_db.quickRefItems)
          ..where((t) => t.refId.equals(refId)))
        .getSingleOrNull();
  }

  @override
  Future<Map<String, int>> progressMap() async {
    final rows = await _db.select(_db.quickRefProgress).get();
    return {for (final r in rows) r.refId: r.status};
  }

  @override
  Future<void> markProgress(String refId, int status) async {
    final existing = await (_db.select(_db.quickRefProgress)
          ..where((t) => t.refId.equals(refId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.quickRefProgress).insert(
            QuickRefProgressCompanion.insert(
              refId: refId,
              status: Value(status),
              seenCount: const Value(1),
            ),
          );
    } else {
      await (_db.update(_db.quickRefProgress)
            ..where((t) => t.refId.equals(refId)))
          .write(QuickRefProgressCompanion(
        status: Value(status),
        seenCount: Value(existing.seenCount + 1),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  QuickRefItem _map(QueryRow r) => QuickRefItem(
        id: r.read<int>('id'),
        refId: r.read<String>('ref_id'),
        category: r.read<String>('category'),
        title: r.read<String>('title'),
        contentMd: r.read<String>('content_md'),
        keywords: r.read<String>('keywords'),
        tip: r.read<String>('tip'),
        sourceRef: r.read<String?>('source_ref'),
      );
}