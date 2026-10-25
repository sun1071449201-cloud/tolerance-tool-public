import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/chapter_learning.dart';

/// 读取 assets/data/book_learning.json（章节学习卡）。
class BookLearningService {
  static Map<String, ChapterLearning>? _cache;

  static Future<Map<String, ChapterLearning>> load() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/data/book_learning.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final chapters = map['chapters'] as Map<String, dynamic>? ?? const {};
      _cache = {
        for (final e in chapters.entries)
          if (e.value is Map<String, dynamic>)
            e.key: ChapterLearning.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      _cache = const {};
    }
    return _cache!;
  }
}
