import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/chapter_learning.dart';
import '../state/book_providers.dart';
import '../widgets/eng_sketches.dart';
import '../widgets/reader_markdown.dart';
import '../widgets/states.dart';
import 'chapter_reading_page.dart';
import 'global_search_page.dart';

/// 速查详情页：Markdown 正文 + 关联经验卡片 + 看过/掌握状态。
class QuickRefDetailPage extends ConsumerStatefulWidget {
  const QuickRefDetailPage({super.key, required this.refId});

  final String refId;

  @override
  ConsumerState<QuickRefDetailPage> createState() => _QuickRefDetailPageState();
}

class _QuickRefDetailPageState extends ConsumerState<QuickRefDetailPage> {
  bool _autoSeen = false;

  Future<void> _mark(int status, {bool silent = false}) async {
    final key = widget.refId.trim();
    if (key.isEmpty) return;
    await ref.read(quickRefRepositoryProvider).markProgress(key, status);
    ref.invalidate(quickRefProgressProvider);
    if (!mounted || silent) return;
    const labels = ['未看', '看过', '掌握'];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('已标记为：${labels[status]}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = widget.refId.trim();
    final itemAsync = ref.watch(quickRefItemProvider(key));
    final progress =
        ref.watch(quickRefProgressProvider).valueOrNull ?? const <String, int>{};
    final status = progress[key] ?? 0;
    final Map<String, ChapterLearning> learningMap =
        ref.watch(bookLearningProvider).valueOrNull ?? const {};
    final relatedChapters = [
      for (final e in learningMap.entries)
        if (e.value.quickRefs.contains(key)) e.key,
    ];

    return Scaffold(
      appBar: AppBar(
        title: itemAsync.whenOrNull(data: (i) => Text(i.title)) ??
            const Text('速查'),
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('速查条目加载失败：$e');
          return EmptyState(
            icon: Icons.search_off,
            title: '这条速查内容暂时找不到',
            subtitle: '可能是数据更新了，或这条链接指向了旧条目。',
            action: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const GlobalSearchPage(),
              )),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('全局搜索'),
            ),
          );
        },
        data: (item) {
          // 打开即算“看过”；只自动记一次，不覆盖“掌握”。
          if (!_autoSeen) {
            _autoSeen = true;
            if (status == 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _mark(1, silent: true);
              });
            }
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(item.category,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.primary, letterSpacing: 1)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('掌握状态：', style: TextStyle(fontSize: 12)),
                  ChoiceChip(
                    label: const Text('未看', style: TextStyle(fontSize: 11)),
                    selected: status == 0,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _mark(0),
                  ),
                  ChoiceChip(
                    label: const Text('看过', style: TextStyle(fontSize: 11)),
                    selected: status == 1,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _mark(1),
                  ),
                  ChoiceChip(
                    label: const Text('掌握', style: TextStyle(fontSize: 11)),
                    selected: status == 2,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _mark(2),
                  ),
                ],
              ),
              if (relatedChapters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('相关章节：',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                      for (final chapterKey in relatedChapters)
                        ActionChip(
                          label: Text(chapterKey.split('.').last,
                              style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    ChapterReadingPage(chapterKey: chapterKey)),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              MarkdownBody(
                data: item.contentMd,
                softLineBreak: true,
                extensionSet: readerMarkdownExtensions,
                builders: {'code': DiagramCodeBuilder()},
                styleSheet:
                    MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.7),
                  tableBorder: TableBorder.all(color: scheme.outlineVariant),
                  tableColumnWidth: FixedColumnWidth(
                      MediaQuery.sizeOf(context).width < 380
                          ? 96
                          : (MediaQuery.sizeOf(context).width > 700
                              ? 150
                              : 112)),
                  tableCellsPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.tertiary, width: 1),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates,
                            size: 17, color: scheme.onTertiaryContainer),
                        const SizedBox(width: 6),
                        Text('工程经验卡片',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onTertiaryContainer)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(item.tip,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                color: scheme.onTertiaryContainer, height: 1.5)),
                  ],
                ),
              ),
              if (item.sourceRef != null && item.sourceRef!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('参考：${item.sourceRef}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
