import 'package:drift/drift.dart';

import '../../domain/ports/user_data_repository.dart';
import '../database/app_database.dart';

class DriftReadingUserDataRepository implements ReadingUserDataRepository {
  DriftReadingUserDataRepository(this._db);

  final AppDatabase _db;

  @override
  Future<double> progressOf(String bookId, String chapterKey) async {
    final row = await (_db.select(_db.readingProgress)
          ..where((t) =>
              t.bookId.equals(bookId) & t.chapterKey.equals(chapterKey)))
        .getSingleOrNull();
    return row?.offsetPx ?? 0;
  }

  @override
  Future<void> saveProgress({
    required String bookId,
    required String chapterKey,
    required double offsetPx,
  }) async {
    final updated = await (_db.update(_db.readingProgress)
          ..where(
              (t) => t.bookId.equals(bookId) & t.chapterKey.equals(chapterKey)))
        .write(ReadingProgressCompanion(
      offsetPx: Value(offsetPx),
      updatedAt: Value(DateTime.now()),
    ));
    if (updated == 0) {
      await _db.into(_db.readingProgress).insert(ReadingProgressCompanion.insert(
            bookId: bookId,
            chapterKey: chapterKey,
            offsetPx: Value(offsetPx),
          ));
    }
  }

  @override
  Future<List<ReadingProgressData>> allReadingProgress() {
    return _db.select(_db.readingProgress).get();
  }

  @override
  Future<void> restoreProgress({
    required String bookId,
    required String chapterKey,
    required double offsetPx,
  }) {
    return saveProgress(
      bookId: bookId,
      chapterKey: chapterKey,
      offsetPx: offsetPx,
    );
  }

  @override
  Future<Map<String, int>> chapterLearningMap() async {
    final rows = await _db.select(_db.chapterLearningProgress).get();
    return {for (final r in rows) r.chapterKey: r.status};
  }

  @override
  Future<void> markChapterLearning(String chapterKey, int status,
      {int? score}) async {
    final existing = await (_db.select(_db.chapterLearningProgress)
          ..where((t) => t.chapterKey.equals(chapterKey)))
        .getSingleOrNull();
    final nextStatus =
        (existing?.status ?? 0) > status ? existing!.status : status;
    final best = (existing?.bestScore ?? 0) > (score ?? 0)
        ? existing!.bestScore
        : (score ?? 0);
    if (existing == null) {
      await _db.into(_db.chapterLearningProgress).insert(
            ChapterLearningProgressCompanion.insert(
              chapterKey: chapterKey,
              status: Value(status),
              bestScore: Value(score ?? 0),
            ),
          );
    } else {
      await (_db.update(_db.chapterLearningProgress)
            ..where((t) => t.chapterKey.equals(chapterKey)))
          .write(ChapterLearningProgressCompanion(
        status: Value(nextStatus),
        bestScore: Value(best),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  @override
  Future<List<ChapterLearningProgressData>> allChapterLearning() {
    return _db.select(_db.chapterLearningProgress).get();
  }

  @override
  Future<void> restoreChapterLearning({
    required String chapterKey,
    required int status,
    required int bestScore,
  }) async {
    await _db.into(_db.chapterLearningProgress).insertOnConflictUpdate(
          ChapterLearningProgressCompanion(
            chapterKey: Value(chapterKey),
            status: Value(status),
            bestScore: Value(bestScore),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<List<QuickRefProgressData>> allQuickRefProgress() {
    return _db.select(_db.quickRefProgress).get();
  }

  @override
  Future<void> restoreQuickRefProgress({
    required String refId,
    required int status,
    required int seenCount,
  }) async {
    await _db.into(_db.quickRefProgress).insertOnConflictUpdate(
          QuickRefProgressCompanion(
            refId: Value(refId),
            status: Value(status),
            seenCount: Value(seenCount),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<List<VocabProgressData>> allVocabProgress() {
    return _db.select(_db.vocabProgress).get();
  }

  @override
  Future<Set<String>> recentDailyTitles({int days = 30}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.subtract(Duration(days: days));
    final rows = await _db.select(_db.dailyHistory).get();
    return {
      for (final r in rows)
        if (r.shownAt.isAfter(cutoff) && r.shownAt.isBefore(today)) r.title,
    };
  }

  @override
  Future<void> recordDailyTitles(String dayKey, List<String> titles) async {
    for (final title in titles) {
      await _db.into(_db.dailyHistory).insert(
            DailyHistoryCompanion.insert(
              dayKey: dayKey,
              title: title,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  @override
  Future<void> restoreVocabProgress({
    required int wordId,
    required int status,
    required int seenCount,
    required int intervalDays,
    required DateTime? dueAt,
    required int lapses,
  }) async {
    await _db.into(_db.vocabProgress).insertOnConflictUpdate(
          VocabProgressCompanion(
            wordId: Value(wordId),
            status: Value(status),
            seenCount: Value(seenCount),
            intervalDays: Value(intervalDays),
            dueAt: Value(dueAt),
            lapses: Value(lapses),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<String?> lastReadChapter(String bookId) async {
    final row = await (_db.select(_db.readingProgress)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row?.chapterKey;
  }

  @override
  Future<Bookmark> addBookmark({
    required String bookId,
    required String chapterKey,
    required int segmentIndex,
    required String excerpt,
    String? note,
    String? anchor,
  }) async {
    final id = await _db.into(_db.bookmarks).insert(BookmarksCompanion.insert(
          bookId: bookId,
          chapterKey: chapterKey,
          segmentIndex: Value(segmentIndex),
          excerpt: excerpt,
          note: Value(note),
          anchor: Value(anchor),
        ));
    return Bookmark(
      id: id,
      bookId: bookId,
      chapterKey: chapterKey,
      segmentIndex: segmentIndex,
      excerpt: excerpt,
      note: note,
      anchor: anchor,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<Bookmark>> bookmarksForChapter(String chapterKey) {
    return (_db.select(_db.bookmarks)
          ..where((t) => t.chapterKey.equals(chapterKey))
          ..orderBy([(t) => OrderingTerm.asc(t.segmentIndex)]))
        .get();
  }

  @override
  Future<List<Bookmark>> allBookmarks() {
    return (_db.select(_db.bookmarks)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  @override
  Future<void> deleteBookmarks(List<int> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(_db.bookmarks)..where((t) => t.id.isIn(ids))).go();
  }

  @override
  Future<Map<String, bool>> readMarks() async {
    final rows = await _db.select(_db.chapterReadMarks).get();
    return {for (final r in rows) r.chapterKey: r.isRead};
  }

  @override
  Future<void> setRead(String chapterKey, {bool isRead = true}) async {
    final existing = await (_db.select(_db.chapterReadMarks)
          ..where((t) => t.chapterKey.equals(chapterKey)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.chapterReadMarks).insert(
            ChapterReadMarksCompanion.insert(
              chapterKey: chapterKey,
              isRead: Value(isRead),
            ),
          );
    } else {
      await (_db.update(_db.chapterReadMarks)
            ..where((t) => t.chapterKey.equals(chapterKey)))
          .write(ChapterReadMarksCompanion(isRead: Value(isRead)));
    }
  }

  @override
  Future<int> addCustomTips(List<DesignTipsCompanion> tips) async {
    var count = 0;
    await _db.batch((b) {
      for (final t in tips) {
        // 打上 custom_import 标记（区分“我的笔记”与系统知识）。
        b.insert(
            _db.designTips,
            t.copyWith(isCustom: const Value(true)));
        count++;
      }
    });
    return count;
  }

  @override
  Future<List<DesignTip>> allDesignTips() {
    return (_db.select(_db.designTips)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
  }

  // ---- 收藏 ----

  @override
  Future<void> addFavorite({
    required String kind,
    required String title,
    required String subtitle,
    required String targetKey,
    String? targetAnchor,
  }) async {
    final existing = await isFavorited(targetKey);
    if (existing) return; // 幂等
    await _db.into(_db.favorites).insert(FavoritesCompanion.insert(
          kind: kind,
          title: title,
          subtitle: subtitle,
          targetKey: targetKey,
          targetAnchor: Value(targetAnchor),
        ));
  }

  @override
  Future<List<Favorite>> allFavorites() {
    return (_db.select(_db.favorites)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  @override
  Future<void> deleteFavorite(int id) async {
    await (_db.delete(_db.favorites)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<bool> isFavorited(String targetKey) async {
    final row = await (_db.select(_db.favorites)
          ..where((t) => t.targetKey.equals(targetKey)))
        .getSingleOrNull();
    return row != null;
  }

  // ---- 备份恢复 ----

  @override
  Future<void> restoreBookmark({
    required String bookId,
    required String chapterKey,
    required int segmentIndex,
    required String excerpt,
    String? note,
    String? anchor,
  }) async {
    // 防重复：同 chapter + segment 已有则跳过
    final existing = await (_db.select(_db.bookmarks)
          ..where((t) =>
              t.chapterKey.equals(chapterKey) &
              t.segmentIndex.equals(segmentIndex)))
        .getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.bookmarks).insert(BookmarksCompanion.insert(
          bookId: bookId,
          chapterKey: chapterKey,
          segmentIndex: Value(segmentIndex),
          excerpt: excerpt,
          note: Value(note),
        ));
  }

  @override
  Future<void> restoreReadMark(String chapterKey, {bool isRead = true}) async {
    await setRead(chapterKey, isRead: isRead);
  }

  @override
  Future<void> restoreCustomTip({
    required String title,
    required String body,
    required String category,
  }) async {
    final existing = await (_db.select(_db.designTips)
          ..where((t) => t.title.equals(title) & t.isCustom.equals(true)))
        .getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.designTips).insert(DesignTipsCompanion(
          title: Value(title),
          body: Value(body),
          category: Value(category),
          isCustom: const Value(true),
        ));
  }

  // ---- 查询历史 ----

  @override
  Future<void> addHistory(String queryText, String resultSummary) async {
    // 相同查询去重：先删旧记录再插入（置顶）。
    await (_db.delete(_db.queryHistory)
          ..where((t) => t.queryText.equals(queryText)))
        .go();
    await _db.into(_db.queryHistory)
        .insert(QueryHistoryCompanion.insert(
      queryText: queryText,
      resultSummary: resultSummary,
    ));
    // 只保留最近 50 条。
    final count = await _db.select(_db.queryHistory).get().then((l) => l.length);
    if (count > 50) {
      final old = await (_db.select(_db.queryHistory)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(count - 50))
          .get();
      await (_db.delete(_db.queryHistory)
            ..where((t) => t.id.isIn([for (final o in old) o.id])))
          .go();
    }
  }

  @override
  Future<List<QueryHistoryEntry>> recentHistory({int limit = 20}) async {
    final rows = await (_db.select(_db.queryHistory)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
    return [
      for (final r in rows)
        QueryHistoryEntry(
          id: r.id,
          queryText: r.queryText,
          resultSummary: r.resultSummary,
          createdAt: r.createdAt,
        ),
    ];
  }

  @override
  Future<void> clearHistory() async {
    await _db.delete(_db.queryHistory).go();
  }

  @override
  Future<int> clearUserData({required String what}) async {
    switch (what) {
      case 'history':
        return _db.delete(_db.queryHistory).go();
      case 'cache':
        // 清理用户缓存：书签/进度/已读/收藏/历史全部清空（不可恢复）。
        var n = 0;
        n += await _db.delete(_db.bookmarks).go();
        n += await _db.delete(_db.readingProgress).go();
        n += await _db.delete(_db.chapterReadMarks).go();
        n += await _db.delete(_db.favorites).go();
        n += await _db.delete(_db.queryHistory).go();
        n += await _db.delete(_db.vocabProgress).go();
        n += await _db.delete(_db.dailyHistory).go();
        n += await _db.delete(_db.quickRefProgress).go();
        n += await _db.delete(_db.chapterLearningProgress).go();
        n += await _db.delete(_db.chapterLearningProgress).go();
        return n;
      default:
        return 0;
    }
  }
}