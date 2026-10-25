import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../state/book_providers.dart';
import 'chapter_reading_page.dart';

/// 章节目录页：多级章节结构 + 已读状态 + 上次阅读定位。
class BookTocPage extends ConsumerWidget {
  const BookTocPage({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final marks = ref.watch(readMarksProvider).valueOrNull ?? {};
    final lastRead = ref.watch(lastReadChapterProvider(book.bookId)).valueOrNull;
    BookNode? lastNode;
    if (lastRead != null) {
      for (final c in book.chapters) {
        if (c.key == lastRead) {
          lastNode = c;
          break;
        }
      }
    }

    final node = lastNode;

    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (node != null)
            Card(
              color: scheme.primaryContainer,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChapterReadingPage(chapterKey: node.key),
                )),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '上次读到：${node.title}（点击继续）',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: scheme.onPrimaryContainer),
                    ],
                  ),
                ),
              ),
            ),
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '✓ = 已读章节。阅读页底部可“标记为已读”；进入章节自动恢复上次阅读位置。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < book.chapters.length; i++)
            _ChapterTile(
              index: i,
              node: book.chapters[i],
              isRead: marks[book.chapters[i].key] ?? false,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.index,
    required this.node,
    required this.isRead,
  });

  final int index;
  final BookNode node;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 14,
          backgroundColor:
              isRead ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: isRead
              ? Icon(Icons.check, size: 16, color: scheme.primary)
              : Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold),
                ),
        ),
        title: Text(
          node.title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isRead ? scheme.onSurfaceVariant : scheme.onSurface),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChapterReadingPage(chapterKey: node.key),
        )),
      ),
    );
  }
}
