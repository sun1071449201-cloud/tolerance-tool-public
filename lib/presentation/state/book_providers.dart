import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/book_repositories.dart';
import '../../data/repositories/learning_repositories.dart';
import '../../domain/models/book_models.dart';
import '../../domain/models/chapter_learning.dart';
import '../../domain/services/book_learning_service.dart';
import '../../domain/models/knowledge_models.dart';
import '../../domain/ports/book_repository.dart';
import '../../domain/ports/learning_repository.dart';
import '../../domain/ports/user_data_repository.dart';
import '../../domain/services/daily_service.dart';
import 'providers.dart';

export 'providers.dart' show userDataRepositoryProvider;
export '../../domain/ports/user_data_repository.dart'
    show QueryHistoryEntry;

// userDataRepositoryProvider 统一定义在 providers.dart（本文件经 import 复用）。

/// 每本书的已读标记映射。
final readMarksProvider =
    FutureProvider<Map<String, bool>>((ref) {
  return ref.watch(userDataRepositoryProvider).readMarks();
});

/// 每本书最近读过的章节（无记录为 null）。
final lastReadChapterProvider =
    FutureProvider.family<String?, String>(
        (ref, bookId) => ref.watch(userDataRepositoryProvider).lastReadChapter(bookId));

/// 每章保存的滚动位置（family 键 = "bookId|chapterKey"）。
final chapterProgressProvider =
    FutureProvider.family<double, String>((ref, arg) {
  final parts = arg.split('|');
  return ref.watch(userDataRepositoryProvider).progressOf(parts[0], parts[1]);
});

/// 每章的书签列表。
final bookmarksForChapterProvider =
    FutureProvider.family<List<Bookmark>, String>((ref, chapterKey) {
  return ref.watch(userDataRepositoryProvider).bookmarksForChapter(chapterKey);
});

/// 全部书签（管理页用）。
final allBookmarksProvider =
    FutureProvider<List<Bookmark>>((ref) {
  return ref.watch(userDataRepositoryProvider).allBookmarks();
});

/// 全部收藏（首页看板用）。
final allFavoritesProvider = FutureProvider<List<Favorite>>((ref) {
  return ref.watch(userDataRepositoryProvider).allFavorites();
});

/// 查询历史（最近记录）。
final queryHistoryProvider =
    FutureProvider<List<QueryHistoryEntry>>((ref) {
  return ref.watch(userDataRepositoryProvider).recentHistory(limit: 20);
});

/// 查询页知识卡 / 今日知识点 → 书籍章节 的跳转请求（MainShell 监听后
/// 切 Tab 并打开阅读页；anchor 为节号，实现段级精准定位）。
final chapterOpenRequestProvider = StateProvider<ChapterJump?>((ref) => null);

/// 全局搜索页 → 查询页 的预填请求（MainShell 切到查询 Tab 后由查询页消费）。
final pendingQueryProvider = StateProvider<String?>((ref) => null);

/// 主题模式（system/light/dark）+ 色板名，持久化到 app_settings。
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._settings) : super(ThemeMode.system);

  final SettingsRepository _settings;
  static const _key = 'theme_mode';

  Future<void> load() async {
    final v = await _settings.get(_key);
    var matched = ThemeMode.system;
    for (final m in ThemeMode.values) {
      if (m.name == v) {
        matched = m;
        break;
      }
    }
    state = matched;
  }

  Future<void> choose(ThemeMode mode) async {
    state = mode;
    await _settings.set(_key, mode.name);
  }
}

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
        (ref) => ThemeModeController(ref.watch(settingsRepositoryProvider)));

/// 色板名（industrial/emerald/violet/amber），持久化。
class SeedColorController extends StateNotifier<String> {
  SeedColorController(this._settings) : super('industrial');

  final SettingsRepository _settings;
  static const _key = 'seed_color';

  Future<void> load() async {
    state = await _settings.get(_key) ?? 'industrial';
  }

  Future<void> choose(String name) async {
    state = name;
    await _settings.set(_key, name);
  }
}

final seedColorControllerProvider =
    StateNotifierProvider<SeedColorController, String>(
        (ref) => SeedColorController(ref.watch(settingsRepositoryProvider)));

final bookRepositoryProvider =
    Provider<BookRepository>((ref) => AssetBookRepository());

final vocabRepositoryProvider =
    Provider<VocabRepository>((ref) => DriftVocabRepository(ref.watch(databaseProvider)));

final dailyFactsRepositoryProvider = Provider<DailyFactsRepository>(
    (ref) => DriftDailyFactsRepository(ref.watch(databaseProvider)));

final quickRefRepositoryProvider = Provider<QuickRefRepository>(
    (ref) => DriftQuickRefRepository(ref.watch(databaseProvider)));

/// 速查检索（family 键 = 搜索词；空串 = 浏览全部）。
final quickRefQueryProvider =
    FutureProvider.family<List<QuickRefItem>, String>(
        (ref, query) => ref.watch(quickRefRepositoryProvider).search(query));

/// 单个速查条目（按 ref_id；缺失时抛异常而非返回 null）。
final quickRefItemProvider =
    FutureProvider.family<QuickRefItem, String>((ref, refId) async {
  final item = await ref.watch(quickRefRepositoryProvider).byRefId(refId);
  if (item == null) throw StateError('未找到速查条目：$refId');
  return item;
});

/// 数据集模式：demo = 演示库（未完整核对），standard = 标准库（已核对）。
final datasetModeProvider =
    FutureProvider<String>((ref) async {
  final v = await ref.watch(settingsRepositoryProvider).get('dataset_mode');
  return (v == null || v.isEmpty) ? 'demo' : v;
});

/// 每日知识点（按本地日期为 family 键：同一天稳定、跨天刷新）。
final dailyTipsProvider =
    FutureProvider.family<List<DailyTip>, String>((ref, dayKey) {
  final service = DailyService(
    ref.watch(dailyFactsRepositoryProvider),
    ref.watch(knowledgeRepositoryProvider),
    ref.watch(quickRefRepositoryProvider),
    ref.watch(userDataRepositoryProvider),
  );
  return service.todays(DateTime.now());
});

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => DriftSettingsRepository(ref.watch(databaseProvider)));

final booksProvider =
    FutureProvider<List<Book>>((ref) => ref.watch(bookRepositoryProvider).loadBooks());

final chapterContentProvider = FutureProvider.family<ChapterContent, String>(
    (ref, chapterKey) => ref.watch(bookRepositoryProvider).loadChapter(chapterKey));

/// 词库检索（family 键 = 搜索词；空串 = 浏览全部）。
final vocabQueryProvider =
    FutureProvider.family<List<VocabWord>, String>(
        (ref, query) => ref.watch(vocabRepositoryProvider).search(query));

/// 章节学习卡（assets/data/book_learning.json）。
final bookLearningProvider = FutureProvider<Map<String, ChapterLearning>>(
    (ref) => BookLearningService.load());

/// 章节学习状态：chapterKey -> 0 未学 / 1 看过 / 2 掌握。
final chapterLearningProvider = FutureProvider<Map<String, int>>(
    (ref) => ref.watch(userDataRepositoryProvider).chapterLearningMap());

/// 工程速查掌握状态：refId -> 0 未看 / 1 看过 / 2 掌握。
final quickRefProgressProvider = FutureProvider<Map<String, int>>(
    (ref) => ref.watch(quickRefRepositoryProvider).progressMap());

/// 英语背诵进度：wordId -> 0/1/2。
final vocabProgressProvider = FutureProvider<Map<int, int>>(
    (ref) => ref.watch(vocabRepositoryProvider).progressMap());

/// 今天到期需要复习的已背词。
final vocabDueProvider = FutureProvider<Set<int>>(
    (ref) => ref.watch(vocabRepositoryProvider).dueWordIds());

/// 阅读字号（全局，持久化到 app_settings）。
class FontScaleController extends StateNotifier<FontScale> {
  FontScaleController(this._settings) : super(FontScale.medium);

  final SettingsRepository _settings;
  static const _key = 'reading_font';

  Future<void> load() async {
    state = FontScale.fromName(await _settings.get(_key));
  }

  Future<void> choose(FontScale scale) async {
    state = scale;
    await _settings.set(_key, scale.name);
  }
}

final fontScaleControllerProvider =
    StateNotifierProvider<FontScaleController, FontScale>(
        (ref) => FontScaleController(ref.watch(settingsRepositoryProvider)));