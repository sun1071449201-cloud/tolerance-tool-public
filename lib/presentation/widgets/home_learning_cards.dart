import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../screens/chapter_reading_page.dart';
import '../screens/vocab_page.dart';
import '../state/book_providers.dart';

/// 首页学习入口：继续上次阅读 + 今日待复习单词。
class HomeLearningCards extends ConsumerWidget {
  const HomeLearningCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Column(
      children: [
        _ContinueReadingCard(),
        _DueVocabCard(),
      ],
    );
  }
}

class _ContinueReadingCard extends ConsumerWidget {
  const _ContinueReadingCard();

  String _titleOf(Book book, String key) {
    String? found;
    void walk(List<BookNode> nodes) {
      for (final n in nodes) {
        if (n.key == key) found = n.title;
        if (n.children.isNotEmpty) walk(n.children);
      }
    }

    walk(book.chapters);
    return found ?? key;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    return booksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (books) {
        for (final book in books) {
          final last =
              ref.watch(lastReadChapterProvider(book.bookId)).valueOrNull;
          if (last == null || last.isEmpty) continue;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: const Text('继续上次阅读'),
              subtitle: Text(
                '${book.title} · ${_titleOf(book, last)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChapterReadingPage(chapterKey: last),
              )),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _DueVocabCard extends ConsumerWidget {
  const _DueVocabCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(vocabDueProvider).valueOrNull?.length ?? 0;
    if (due == 0) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.school_outlined),
        title: Text('今日有 $due 个单词待复习'),
        subtitle: const Text('按 1/3/7/30 天间隔排的，趁热过一遍'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VocabPage()),
          );
          if (!context.mounted) return;
          ref.invalidate(vocabDueProvider);
          ref.invalidate(vocabProgressProvider);
        },
      ),
    );
  }
}