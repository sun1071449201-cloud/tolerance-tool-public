import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/exceptions.dart';
import '../../core/utils/format.dart';
import '../../data/database/app_database.dart';
import '../../domain/models/book_models.dart';
import '../../domain/models/tolerance_models.dart';
import '../../domain/parsing/designation_parser.dart';
import '../state/book_providers.dart';
import '../state/providers.dart';
import '../widgets/states.dart';
import 'chapter_reading_page.dart';
import 'quick_ref_detail_page.dart';

/// 全局聚合搜索：一次输入，同时检索公差配合、英语词库、书籍章节、速查条目。
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key, this.initialQuery});

  /// 初始搜索词（划词搜索跳入时传入）。
  final String? initialQuery;

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  late final _controller = TextEditingController(text: widget.initialQuery ?? '');
  late String _query = widget.initialQuery?.trim() ?? '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(globalSearchProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('全局搜索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜索公差 / 单词 / 章节 / 速查条目',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? const EmptyState(
                    icon: Icons.travel_explore,
                    title: '输入关键词开始检索',
                    subtitle: '公差 · 单词 · 章节 · 速查 · 完全离线',
                  )
                : resultsAsync.when(
                    loading: () => const LoadingState(hint: '四路检索中…'),
                    error: (e, _) =>
                        EmptyState(icon: Icons.error_outline, title: '检索失败：$e'),
                    data: (r) => _ResultsView(results: r, query: _query),
                  ),
          ),
        ],
      ),
    );
  }
}

class GlobalSearchResults {
  const GlobalSearchResults({
    this.fit,
    this.parseError,
    required this.words,
    required this.refs,
    required this.chapterHits,
    required this.bookHits,
  });

  final FitQueryResult? fit;
  final String? parseError;
  final List<VocabWord> words;
  final List<QuickRefItem> refs;
  final List<ChapterHit> chapterHits;
  final List<ChapterSearchHit> bookHits;
}

class ChapterHit {
  const ChapterHit({required this.bookTitle, required this.node});

  final String bookTitle;
  final BookNode node;
}

final globalSearchProvider =
    FutureProvider.family<GlobalSearchResults, String>((ref, query) async {
  final q = query.trim();

  // 1) 公差配合：能解析成公差代号就出实算结果
  FitQueryResult? fit;
  String? parseError;
  if (q.isNotEmpty) {
    try {
      final d = DesignationParser.parse(q);
      fit = await ref
          .watch(toleranceQueryServiceProvider)
          .query(d, ref.watch(standardContextProvider));
    } on ParseException catch (e) {
      parseError = e.message;
    } on DataNotSeedException catch (e) {
      parseError = e.message;
    } catch (_) {
      parseError = null;
    }
  }

  // 2) 英语词库 / 3) 速查条目
  final words = q.isEmpty ? <VocabWord>[] : await ref.watch(vocabRepositoryProvider).search(q);
  final refs = q.isEmpty ? <QuickRefItem>[] : await ref.watch(quickRefRepositoryProvider).search(q);

  // 4) 书籍章节（标题包含，大小写不敏感）
  final lower = q.toLowerCase();
  final chapterHits = <ChapterHit>[];
  if (q.isNotEmpty) {
    for (final b in await ref.watch(bookRepositoryProvider).loadBooks()) {
      if (b.title.toLowerCase().contains(lower)) {
        for (final c in b.chapters) {
          chapterHits.add(ChapterHit(bookTitle: b.title, node: c));
        }
        continue;
      }
      for (final c in b.chapters) {
        if (c.title.toLowerCase().contains(lower)) {
          chapterHits.add(ChapterHit(bookTitle: b.title, node: c));
        }
      }
    }
  }

  final titleKeys = chapterHits.map((h) => h.node.key).toSet();
  final bookHits = q.isEmpty
      ? <ChapterSearchHit>[]
      : (await ref.watch(bookRepositoryProvider).searchContent(q))
          .where((h) => !titleKeys.contains(h.chapterKey))
          .toList();

  return GlobalSearchResults(
    fit: fit,
    parseError: parseError,
    words: words.take(20).toList(),
    refs: refs.take(20).toList(),
    chapterHits: chapterHits.take(20).toList(),
    bookHits: bookHits.take(20).toList(),
  );
});

class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.results, required this.query});

  final GlobalSearchResults results;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final r = results;
    final isEmpty = r.fit == null &&
        r.parseError == null &&
        r.words.isEmpty &&
        r.refs.isEmpty &&
        r.chapterHits.isEmpty &&
        r.bookHits.isEmpty;

    if (isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: '没有匹配的公差、单词、章节或速查条目',
        subtitle: '换个关键词试试（支持中英、配合代号）',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (r.fit != null) ..._fitSection(context, ref, r.fit!),
        if (r.parseError != null)
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('公差解析提示：${r.parseError}',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        if (r.refs.isNotEmpty) ...[
          _header(context, '速查条目', '${r.refs.length}'),
          for (final item in r.refs)
            ListTile(
              dense: true,
              leading: const Icon(Icons.grid_view, size: 18),
              title: Text(item.title),
              subtitle: Text(item.tip,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => QuickRefDetailPage(refId: item.refId),
              )),
            ),
        ],
        if (r.words.isNotEmpty) ...[
          _header(context, '英语词汇', '${r.words.length}'),
          for (final w in r.words)
            ListTile(
              dense: true,
              leading: const Icon(Icons.translate, size: 18),
              title: Text(w.en),
              subtitle: Text(w.zh),
            ),
        ],
        if (r.chapterHits.isNotEmpty) ...[
          _header(context, '书籍章节', '${r.chapterHits.length}'),
          for (final hit in r.chapterHits)
            ListTile(
              dense: true,
              leading: const Icon(Icons.menu_book, size: 18),
              title: Text(hit.node.title),
              subtitle: Text(hit.bookTitle),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ChapterReadingPage(chapterKey: hit.node.key),
              )),
            ),
        ],
        if (r.bookHits.isNotEmpty) ...[
          _header(context, '书籍正文', '${r.bookHits.length}'),
          for (final hit in r.bookHits)
            ListTile(
              dense: true,
              leading: const Icon(Icons.article_outlined, size: 18),
              title: Text(hit.chapterTitle),
              subtitle: Text('${hit.bookTitle} · ${hit.snippet}',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChapterReadingPage(
                  chapterKey: hit.chapterKey,
                  anchor: hit.anchor,
                  searchQuery: query,
                ),
              )),
            ),
        ],
      ],
    );
  }

  List<Widget> _fitSection(
      BuildContext context, WidgetRef ref, FitQueryResult fit) {
    return [
      _header(context, '公差配合', '实算结果'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(fit.input.display,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                fit.fitType == null
                    ? '仅孔公差带'
                    : '${fit.fitType!.label} · 最大 ${formatUmSigned(fit.xMaxUm ?? 0)} μm · 最小 ${formatUmSigned(fit.xMinUm ?? 0)} μm',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    ref.read(pendingQueryProvider.notifier).state =
                        fit.input.display;
                  },
                  icon: const Icon(Icons.open_in_full, size: 14),
                  label: const Text('到查询页看公差带图'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
    ];
  }

  Widget _header(BuildContext context, String label, String count) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: scheme.primary),
          const SizedBox(width: 6),
          Text('$label（$count）',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}