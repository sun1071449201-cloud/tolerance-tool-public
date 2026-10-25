import '../../data/database/app_database.dart';

/// 机械英语词库访问接口（FTS 中英双向检索）。
abstract class VocabRepository {
  Future<List<VocabWord>> all();

  /// 中英双向模糊检索：英文词、中文释义都能命中。
  Future<List<VocabWord>> search(String query);

  /// wordId -> status（0 未学 / 1 还不熟 / 2 已背）。
  Future<Map<int, int>> progressMap();

  Future<void> markWord(int wordId, {required bool known});

  Future<void> markSeen(int wordId);

  /// 清空该词的背诵状态（用于误点“已背”后恢复未学）。
  Future<void> clearWord(int wordId);

  /// 今天到期需要复习的已背词。
  Future<Set<int>> dueWordIds();
}

/// 每日知识点推荐池访问接口。
abstract class DailyFactsRepository {
  Future<List<DailyFact>> all();
}

/// 工程速查与选型条目（FTS 全文检索）。
abstract class QuickRefRepository {
  Future<List<QuickRefItem>> all();

  /// 中文/关键词模糊检索。
  Future<List<QuickRefItem>> search(String query);

  Future<QuickRefItem?> byRefId(String refId);

  /// refId -> 0 未看 / 1 看过 / 2 掌握。
  Future<Map<String, int>> progressMap();

  Future<void> markProgress(String refId, int status);
}