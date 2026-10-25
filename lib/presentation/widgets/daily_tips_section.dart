import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../../domain/services/daily_service.dart';
import '../state/book_providers.dart';

/// 查询页顶部的「今日知识点」：每天从推荐池确定性抽取 3 条，
/// 点击精准跳转到书籍对应小节（锚点）。
class DailyTipsSection extends ConsumerWidget {
  const DailyTipsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayKey = DailyService.dayKeyOf(DateTime.now());
    final tipsAsync = ref.watch(dailyTipsProvider(dayKey));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.today_outlined, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Text('今日知识点',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('每天更新 3 条 · 点击直达书籍解析',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 8),
        tipsAsync.when(
          loading: () => const SizedBox(
              height: 48,
              child: Center(child: LinearProgressIndicator(minHeight: 2))),
          error: (e, _) => Text('知识点加载失败：$e',
              style: Theme.of(context).textTheme.bodySmall),
          data: (tips) => Column(
            children: [
              for (final tip in tips)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      final chapterKey = tip.chapterKey.trim();
                      final quickRefId = tip.quickRefId?.trim();
                      final hasChapter = chapterKey.isNotEmpty;
                      final hasQuickRef =
                          quickRefId != null && quickRefId.isNotEmpty;
                      if (!hasChapter && !hasQuickRef) {
                        // 无任何关联：友好提示，不构造跳转请求
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('该知识点暂无关联详情')),
                        );
                        return;
                      }
                      ref.read(chapterOpenRequestProvider.notifier).state =
                          ChapterJump(
                        chapterKey: hasChapter ? chapterKey : null,
                        anchor: tip.anchor?.trim(),
                        quickRefId: hasQuickRef ? quickRefId : null,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 15, color: scheme.tertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      tip.sourceLabel == '我的笔记' ? '📝' : '💡',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(tip.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: tip.sourceLabel == '我的笔记'
                                            ? scheme.tertiaryContainer
                                            : scheme.secondaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(tip.sourceLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                  fontSize: 9,
                                                  color: tip.sourceLabel ==
                                                          '我的笔记'
                                                      ? scheme
                                                          .onTertiaryContainer
                                                      : scheme
                                                          .onSecondaryContainer)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(tip.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(height: 1.35)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 18, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}