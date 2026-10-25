import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../state/book_providers.dart';

/// 首页"我的收藏"看板：显示收藏的公差配合/速查条目/书籍章节，点击直达。
class FavoritesDashboard extends ConsumerWidget {
  const FavoritesDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(allFavoritesProvider);
    final scheme = Theme.of(context).colorScheme;

    return favoritesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (favorites) {
        if (favorites.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, size: 16, color: scheme.tertiary),
                const SizedBox(width: 6),
                Text('我的收藏',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('${favorites.length} 条',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final f in favorites.take(5))
                      ListTile(
                        dense: true,
                        leading: Icon(
                          f.kind == 'tolerance'
                              ? Icons.search
                              : f.kind == 'chapter'
                                  ? Icons.menu_book
                                  : f.kind == 'quickref'
                                      ? Icons.grid_view
                                      : Icons.translate,
                          size: 18,
                          color: scheme.primary,
                        ),
                        title: Text(f.title,
                            style: Theme.of(context).textTheme.bodyMedium),
                        subtitle: Text(f.subtitle,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () {
                            ref.read(userDataRepositoryProvider).deleteFavorite(f.id);
                            ref.invalidate(allFavoritesProvider);
                          },
                        ),
                        onTap: () {
                          final targetKey = f.targetKey.trim();
                          final isChapter =
                              f.kind == 'chapter' && targetKey.isNotEmpty;
                          final isQuickRef =
                              f.kind == 'quickref' && targetKey.isNotEmpty;
                          if (!isChapter && !isQuickRef) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('该收藏暂无可跳转的详情')),
                            );
                            return;
                          }
                          ref.read(chapterOpenRequestProvider.notifier).state =
                              ChapterJump(
                            chapterKey: isChapter ? targetKey : null,
                            anchor: f.targetAnchor?.trim(),
                            quickRefId: isQuickRef ? targetKey : null,
                          );
                        },
                      ),
                    if (favorites.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '…共 ${favorites.length} 条',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}