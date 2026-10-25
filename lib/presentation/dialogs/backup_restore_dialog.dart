import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/backup_service.dart';
import '../state/book_providers.dart';

/// 备份与恢复对话框：导出书签/进度/已读/自定义知识为 JSON，或从 JSON 恢复。
class BackupRestoreDialog extends ConsumerStatefulWidget {
  const BackupRestoreDialog({super.key});

  @override
  ConsumerState<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends ConsumerState<BackupRestoreDialog> {
  String _result = '';
  bool _ok = false;

  Future<void> _export() async {
    final repo = ref.read(userDataRepositoryProvider);
    final bookmarks = await repo.allBookmarks();
    final marks = await repo.readMarks();
    final tips = await repo.allDesignTips();
    final reading = await repo.allReadingProgress();
    final vocab = await repo.allVocabProgress();
    final favorites = await repo.allFavorites();
    final history = await repo.recentHistory(limit: 10000);
    final quickRefs = await repo.allQuickRefProgress();
    final chapterLearning = await repo.allChapterLearning();

    final json = BackupService.encode(
      bookmarks: [
        for (final b in bookmarks)
          {
            'book_id': b.bookId,
            'chapter_key': b.chapterKey,
            'segment_index': b.segmentIndex,
            'anchor': b.anchor,
            'excerpt': b.excerpt,
            'note': b.note,
          },
      ],
      progress: [
        for (final p in reading)
          {
            'book_id': p.bookId,
            'chapter_key': p.chapterKey,
            'offset_px': p.offsetPx,
          },
      ],
      readMarks: [for (final e in marks.entries) {'chapter_key': e.key, 'is_read': e.value}],
      customTips: [
        for (final t in tips)
          if (t.isCustom)
            {'title': t.title, 'body': t.body, 'category': t.category},
      ],
      vocabProgress: [
        for (final v in vocab)
          {
            'word_id': v.wordId,
            'status': v.status,
            'seen_count': v.seenCount,
            'interval_days': v.intervalDays,
            'due_at': v.dueAt?.toIso8601String(),
            'lapses': v.lapses,
          },
      ],
      favorites: [
        for (final f in favorites)
          {
            'kind': f.kind,
            'title': f.title,
            'subtitle': f.subtitle,
            'target_key': f.targetKey,
            'target_anchor': f.targetAnchor,
          },
      ],
      queryHistory: [
        for (final h in history)
          {
            'query_text': h.queryText,
            'result_summary': h.resultSummary,
          },
      ],
      quickRefProgress: [
        for (final q in quickRefs)
          {
            'ref_id': q.refId,
            'status': q.status,
            'seen_count': q.seenCount,
          },
      ],
      chapterLearning: [
        for (final c in chapterLearning)
          {
            'chapter_key': c.chapterKey,
            'status': c.status,
            'best_score': c.bestScore,
          },
      ],
    );

    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('备份 JSON 已复制到剪贴板，粘贴到备忘录/文件即可保存')));
    setState(() { _ok = true; _result = '备份已导出到剪贴板，粘贴保存即可。'; });
  }

  Future<void> _importFile() async {
    const typeGroup = XTypeGroup(
      label: '备份文件 (JSON)', extensions: ['json'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final content = await file.readAsString();
    await _doRestore(content);
  }

  Future<void> _importPaste() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴备份 JSON'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
              labelText: '粘贴备份 JSON 内容', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('恢复')),
        ],
      ),
    );
    if (confirmed == true && controller.text.isNotEmpty) {
      await _doRestore(controller.text);
    }
  }

  Future<void> _doRestore(String json) async {
    try {
      final data = BackupService.decode(json);
      final repo = ref.read(userDataRepositoryProvider);
      var count = 0;
      // 恢复书签
      for (final b in data.bookmarks) {
        repo.restoreBookmark(
          bookId: (b['book_id'] ?? '') as String,
          chapterKey: (b['chapter_key'] ?? '') as String,
          segmentIndex: (b['segment_index'] as num?)?.toInt() ?? 0,
          excerpt: (b['excerpt'] ?? '') as String,
          note: b['note'] as String?,
          anchor: b['anchor'] as String?,
        );
        count++;
      }
      // 恢复已读标记
      for (final r in data.readMarks) {
        repo.restoreReadMark((r['chapter_key'] ?? '') as String,
            isRead: (r['is_read'] as bool?) ?? true);
        count++;
      }
      // 恢复自定义知识
      for (final t in data.customTips) {
        repo.restoreCustomTip(
          title: (t['title'] ?? '') as String,
          body: (t['body'] ?? '') as String,
          category: (t['category'] ?? '我的笔记') as String,
        );
        count++;
      }
      // 恢复阅读进度
      for (final p in data.progress) {
        await repo.restoreProgress(
          bookId: (p['book_id'] ?? '') as String,
          chapterKey: (p['chapter_key'] ?? '') as String,
          offsetPx: (p['offset_px'] as num?)?.toDouble() ?? 0,
        );
        count++;
      }
      // 恢复英语背诵进度
      for (final v in data.vocabProgress) {
        final due = v['due_at'] as String?;
        await repo.restoreVocabProgress(
          wordId: (v['word_id'] as num?)?.toInt() ?? 0,
          status: (v['status'] as num?)?.toInt() ?? 0,
          seenCount: (v['seen_count'] as num?)?.toInt() ?? 0,
          intervalDays: (v['interval_days'] as num?)?.toInt() ?? 0,
          dueAt: due == null ? null : DateTime.tryParse(due),
          lapses: (v['lapses'] as num?)?.toInt() ?? 0,
        );
        count++;
      }
      // 恢复收藏
      for (final f in data.favorites) {
        await repo.addFavorite(
          kind: (f['kind'] ?? '') as String,
          title: (f['title'] ?? '') as String,
          subtitle: (f['subtitle'] ?? '') as String,
          targetKey: (f['target_key'] ?? '') as String,
          targetAnchor: f['target_anchor'] as String?,
        );
        count++;
      }
      // 恢复查询历史
      for (final h in data.queryHistory) {
        await repo.addHistory(
          (h['query_text'] ?? '') as String,
          (h['result_summary'] ?? '') as String,
        );
        count++;
      }
      // 恢复速查掌握状态
      for (final q in data.quickRefProgress) {
        await repo.restoreQuickRefProgress(
          refId: (q['ref_id'] ?? '') as String,
          status: (q['status'] as num?)?.toInt() ?? 0,
          seenCount: (q['seen_count'] as num?)?.toInt() ?? 0,
        );
        count++;
      }
      // 恢复章节学习状态
      for (final c in data.chapterLearning) {
        await repo.restoreChapterLearning(
          chapterKey: (c['chapter_key'] ?? '') as String,
          status: (c['status'] as num?)?.toInt() ?? 0,
          bestScore: (c['best_score'] as num?)?.toInt() ?? 0,
        );
        count++;
      }
      ref.invalidate(readMarksProvider);
      ref.invalidate(allBookmarksProvider);
      ref.invalidate(allFavoritesProvider);
      ref.invalidate(queryHistoryProvider);
      ref.invalidate(vocabProgressProvider);
      ref.invalidate(vocabDueProvider);
      ref.invalidate(quickRefProgressProvider);
      ref.invalidate(chapterLearningProvider);
      if (!mounted) return;
      setState(() { _ok = true; _result = '恢复完成：$count 条数据已写入。'; });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() { _ok = false; _result = '格式错误：${e.message}'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _ok = false; _result = '恢复失败：$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('备份与恢复'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('备份内容包含：书签、阅读进度、已读、自定义知识、背诵进度、收藏、查询历史、速查掌握状态。\n'
                '导出为 JSON 后粘贴保存；恢复时粘贴回去或选择文件。'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('导出备份（复制到剪贴板）'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importFile,
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('从文件恢复'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _importPaste,
                icon: const Icon(Icons.paste, size: 18),
                label: const Text('从粘贴文本恢复'),
              ),
            ),
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_ok ? '✅ $_result' : '⚠ $_result',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('完成')),
      ],
    );
  }
}