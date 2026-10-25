import '../models/book_models.dart';

/// 书籍内容访问接口（实现从 assets/books 读取，完全离线）。
abstract class BookRepository {
  /// 全部书籍（含两级章节树）。
  Future<List<Book>> loadBooks();

  /// 按 key 读取章节正文，并解析章内小节与上一章/下一章。
  Future<ChapterContent> loadChapter(String chapterKey);

  /// 在全部书籍正文中搜索关键词；返回章节、节号和摘要。
  Future<List<ChapterSearchHit>> searchContent(String query, {int limit = 20});
}

/// 轻量设置读写（阅读字号等），存储于 app_settings 表。
abstract class SettingsRepository {
  Future<String?> get(String key);

  Future<void> set(String key, String value);
}