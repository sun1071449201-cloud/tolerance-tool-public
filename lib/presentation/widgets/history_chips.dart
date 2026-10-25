import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/book_providers.dart';

/// 查询历史条：最近查询的可横滑快捷重查入口。
class HistoryChips extends ConsumerWidget {
  const HistoryChips({super.key, required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(queryHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('最近查询',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await ref
                        .read(userDataRepositoryProvider)
                        .clearHistory();
                    ref.invalidate(queryHistoryProvider);
                  },
                  child: Text('清除',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ActionChip(
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(
                      items[i].queryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onPick(items[i].queryText),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
