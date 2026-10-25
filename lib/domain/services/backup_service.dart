import 'dart:convert';

/// 备份/恢复的纯逻辑：JSON 编解码 + 格式校验（可单测）。
/// 实际文件读写由 UI 层通过 file_selector 完成。
class BackupService {
  BackupService._();

  /// 将用户数据序列化为 JSON 字符串。
  static String encode({
    required List<Map<String, dynamic>> bookmarks,
    required List<Map<String, dynamic>> progress,
    required List<Map<String, dynamic>> readMarks,
    required List<Map<String, dynamic>> customTips,
    List<Map<String, dynamic>> vocabProgress = const [],
    List<Map<String, dynamic>> favorites = const [],
    List<Map<String, dynamic>> queryHistory = const [],
    List<Map<String, dynamic>> quickRefProgress = const [],
    List<Map<String, dynamic>> chapterLearning = const [],
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'bookmarks': bookmarks,
      'reading_progress': progress,
      'read_marks': readMarks,
      'custom_tips': customTips,
      'vocab_progress': vocabProgress,
      'favorites': favorites,
      'query_history': queryHistory,
      'quick_ref_progress': quickRefProgress,
      'chapter_learning': chapterLearning,
    });
  }

  /// 解析备份 JSON → 各表数据列表；格式不合法抛 FormatException。
  static ({
    List<Map<String, dynamic>> bookmarks,
    List<Map<String, dynamic>> progress,
    List<Map<String, dynamic>> readMarks,
    List<Map<String, dynamic>> customTips,
    List<Map<String, dynamic>> vocabProgress,
    List<Map<String, dynamic>> favorites,
    List<Map<String, dynamic>> queryHistory,
    List<Map<String, dynamic>> quickRefProgress,
    List<Map<String, dynamic>> chapterLearning,
  }) decode(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    if (!decoded.containsKey('bookmarks') && !decoded.containsKey('custom_tips')) {
      throw const FormatException('缺少 bookmarks 或 custom_tips 字段');
    }
    return (
      bookmarks: _mapList(decoded['bookmarks']),
      progress: _mapList(decoded['reading_progress']),
      readMarks: _mapList(decoded['read_marks']),
      customTips: _mapList(decoded['custom_tips']),
      vocabProgress: _mapList(decoded['vocab_progress']),
      favorites: _mapList(decoded['favorites']),
      queryHistory: _mapList(decoded['query_history']),
      quickRefProgress: _mapList(decoded['quick_ref_progress']),
      chapterLearning: _mapList(decoded['chapter_learning']),
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic v) =>
      v is List ? [for (final e in v) if (e is Map<String, dynamic>) e] : [];
}

/// 收藏条目（查询结果/速查/书籍章节均可收藏）。
class FavoriteEntry {
  const FavoriteEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.targetKey,
    this.targetAnchor,
  });

  final int id;
  final String kind; // tolerance / vocab / chapter / quickref
  final String title;
  final String subtitle;
  final String targetKey; // 查询代号 / 词库 en / 章节键 / 速查 ref_id
  final String? targetAnchor;
}