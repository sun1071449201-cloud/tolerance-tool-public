import '../../data/database/app_database.dart';

/// 用户学习数据：阅读进度、书签、已读标记、自定义知识、收藏、备份。
abstract class ReadingUserDataRepository {
  // ---- 阅读进度 ----
  Future<double> progressOf(String bookId, String chapterKey);
  Future<void> saveProgress({
    required String bookId,
    required String chapterKey,
    required double offsetPx,
  });

  /// 该书最近读过的章节键（无记录返回 null）。
  Future<String?> lastReadChapter(String bookId);

  // ---- 书签 ----
  Future<Bookmark> addBookmark({
    required String bookId,
    required String chapterKey,
    required int segmentIndex,
    required String excerpt,
    String? note,
    String? anchor,
  });

  Future<List<Bookmark>> bookmarksForChapter(String chapterKey);

  Future<List<Bookmark>> allBookmarks();

  Future<void> deleteBookmarks(List<int> ids);

  // ---- 已读标记 ----
  Future<Map<String, bool>> readMarks();

  Future<void> setRead(String chapterKey, {bool isRead = true});

  // ---- 自定义知识（custom_import: true）----
  Future<int> addCustomTips(List<DesignTipsCompanion> tips);

  Future<List<DesignTip>> allDesignTips();

  // ---- 收藏 ----
  Future<void> addFavorite({
    required String kind,
    required String title,
    required String subtitle,
    required String targetKey,
    String? targetAnchor,
  });

  Future<List<Favorite>> allFavorites();

  Future<void> deleteFavorite(int id);

  Future<bool> isFavorited(String targetKey);

  // ---- 备份与恢复 ----
  Future<void> restoreBookmark({
    required String bookId,
    required String chapterKey,
    required int segmentIndex,
    required String excerpt,
    String? note,
    String? anchor,
  });

  Future<void> restoreReadMark(String chapterKey, {bool isRead = true});

  // ---- 完整备份 ----
  Future<List<ReadingProgressData>> allReadingProgress();

  Future<void> restoreProgress({
    required String bookId,
    required String chapterKey,
    required double offsetPx,
  });

  Future<List<VocabProgressData>> allVocabProgress();

  Future<List<QuickRefProgressData>> allQuickRefProgress();

  Future<Map<String, int>> chapterLearningMap();

  Future<void> markChapterLearning(String chapterKey, int status, {int? score});

  Future<List<ChapterLearningProgressData>> allChapterLearning();

  Future<void> restoreChapterLearning({
    required String chapterKey,
    required int status,
    required int bestScore,
  });

  Future<void> restoreQuickRefProgress({
    required String refId,
    required int status,
    required int seenCount,
  });

  // ---- 每日推荐去重 ----
  Future<Set<String>> recentDailyTitles({int days = 30});

  Future<void> recordDailyTitles(String dayKey, List<String> titles);

  Future<void> restoreVocabProgress({
    required int wordId,
    required int status,
    required int seenCount,
    required int intervalDays,
    required DateTime? dueAt,
    required int lapses,
  });

  Future<void> restoreCustomTip({
    required String title,
    required String body,
    required String category,
  });

  // ---- 查询历史 ----
  Future<void> addHistory(String queryText, String resultSummary);

  Future<List<QueryHistoryEntry>> recentHistory({int limit = 20});

  Future<void> clearHistory();

  /// 数据清理：按类别清除用户数据（history / cache）。
  Future<int> clearUserData({required String what});
}

class QueryHistoryEntry {
  const QueryHistoryEntry({
    required this.id,
    required this.queryText,
    required this.resultSummary,
    required this.createdAt,
  });

  final int id;
  final String queryText;
  final String resultSummary;
  final DateTime createdAt;
}