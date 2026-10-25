import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../state/book_providers.dart';
import 'chapter_reading_page.dart';

/// 书签管理页：全部书签 + 批量勾选删除 + 导出（复制 JSON 到剪贴板）。
class BookmarksManagePage extends ConsumerStatefulWidget {
  const BookmarksManagePage({super.key});

  @override
  ConsumerState<BookmarksManagePage> createState() => _BookmarksManagePageState();
}

class _BookmarksManagePageState extends ConsumerState<BookmarksManagePage> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(allBookmarksProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书签'),
        actions: [
          IconButton(
            tooltip: '导出（复制 JSON）',
            icon: const Icon(Icons.ios_share),
            onPressed: () async {
              final list = bookmarksAsync.valueOrNull ?? const [];
              if (list.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              final json = const JsonEncoder.withIndent('  ').convert([
                for (final b in list)
                  {
                    'chapter_key': b.chapterKey,
                    'segment_index': b.segmentIndex,
                    'anchor': b.anchor,
                    'excerpt': b.excerpt,
                    'note': b.note,
                    'created_at': b.createdAt.toIso8601String(),
                  }
              ]);
              await Clipboard.setData(ClipboardData(text: json));
              messenger.showSnackBar(
                  const SnackBar(content: Text('书签已导出到剪贴板（JSON 格式）')));
            },
          ),
        ],
      ),
      body: bookmarksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border, size: 48, color: scheme.outline),
                  const SizedBox(height: 12),
                  const Text('还没有书签'),
                  const Text('在阅读页任意段落右下角点击书签图标即可添加',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Text('已选 ${_selected.length} 项',
                          style: Theme.of(context).textTheme.labelLarge),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _selected.clear()),
                        child: const Text('取消选择'),
                      ),
                      FilledButton.tonal(
                        onPressed: () async {
                          await ref
                              .read(userDataRepositoryProvider)
                              .deleteBookmarks(_selected.toList());
                          ref.invalidate(allBookmarksProvider);
                          setState(() => _selected.clear());
                        },
                        child: const Text('删除所选'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final b in bookmarks)
                      CheckboxListTile(
                        value: _selected.contains(b.id),
                        onChanged: (v) => setState(() {
                          v == true ? _selected.add(b.id) : _selected.remove(b.id);
                        }),
                        title: Text(b.excerpt,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${b.note ?? '无备注'} · ${b.createdAt.month}/${b.createdAt.day}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        secondary: IconButton(
                          tooltip: '打开书签位置',
                          icon: const Icon(Icons.open_in_new, size: 16),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChapterReadingPage(
                                chapterKey: b.chapterKey,
                                anchor: b.anchor,
                                jumpSegment: b.segmentIndex,
                              ),
                            ),
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}