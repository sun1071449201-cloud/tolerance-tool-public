/// 用户学习数据模型：书签、阅读进度、已读标记、设计常识条目。
class BookmarkItem {
  const BookmarkItem({
    required this.id,
    required this.bookId,
    required this.chapterKey,
    required this.segmentIndex,
    required this.excerpt,
    required this.createdAt,
    this.note,
  });

  final int id;
  final String bookId;
  final String chapterKey;
  final int segmentIndex;
  final String excerpt;
  final String? note;
  final DateTime createdAt;
}

class DesignTipRecord {
  const DesignTipRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.isCustom,
    this.chapterKey,
    this.anchor,
  });

  final int id;
  final String title;
  final String body;
  final String category;
  final String? chapterKey;
  final String? anchor;
  final bool isCustom;
}
