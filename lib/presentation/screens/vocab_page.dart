import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../state/book_providers.dart';
import '../widgets/states.dart';

/// Tab 2：机械英语与翻译。词库浏览 + 背诵模式 + FTS 中英双向检索，完全离线。
class VocabPage extends ConsumerStatefulWidget {
  const VocabPage({super.key});

  @override
  ConsumerState<VocabPage> createState() => _VocabPageState();
}

class _VocabPageState extends ConsumerState<VocabPage> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _reciteMode = false;
  String? _letter; // A-Z 首字母筛选（null = 全部）
  final _revealed = <int>{};
  String _statusFilter = 'all';
  int? _lastWordId;
  int _orderSeed = 1;
  bool _shuffle = true;
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStudyPrefs();
  }

  Future<void> _loadStudyPrefs() async {
    final settings = ref.read(settingsRepositoryProvider);
    final parsedSeed =
        int.tryParse(await settings.get('vocab_order_seed') ?? '');
    final seed =
        parsedSeed ?? DateTime.now().millisecondsSinceEpoch % 100000;
    await settings.set('vocab_order_seed', seed.toString());
    final last = int.tryParse(await settings.get('vocab_last_word_id') ?? '');
    final shuffle = (await settings.get('vocab_shuffle')) != '0';
    if (!mounted) return;
    setState(() {
      _orderSeed = seed;
      _lastWordId = last;
      _shuffle = shuffle;
      _prefsLoaded = true;
    });
  }

  Future<void> _saveLastWord(int id) async {
    _lastWordId = id;
    await ref
        .read(settingsRepositoryProvider)
        .set('vocab_last_word_id', id.toString());
  }

  Future<void> _setShuffle(bool value) async {
    final settings = ref.read(settingsRepositoryProvider);
    final seed = DateTime.now().millisecondsSinceEpoch % 100000;
    await settings.set('vocab_shuffle', value ? '1' : '0');
    await settings.set('vocab_order_seed', seed.toString());
    // 重新洗牌前先把最新背诵状态刷回来，避免新队列拿到旧的 progress。
    ref.invalidate(vocabProgressProvider);
    try {
      await ref.read(vocabProgressProvider.future);
    } catch (_) {
      // 读取失败就按原进度继续，下一次进入会重试。
    }
    if (!mounted) return;
    setState(() {
      _shuffle = value;
      _orderSeed = seed;
    });
  }

  static const _letters = [
    'A','B','C','D','E','F','G','H','I','J','K','L','M',
    'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'
  ];

  Future<void> _markBrowse(int id, bool? known) async {
    final repo = ref.read(vocabRepositoryProvider);
    if (known == null) {
      await repo.clearWord(id);
    } else {
      await repo.markWord(id, known: known);
    }
    ref.invalidate(vocabProgressProvider);
    ref.invalidate(vocabDueProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(known == null ? '已恢复为未背' : '已标记为已背'),
    ));
  }

  Widget _buildRecite(WidgetRef ref) {
    if (!_prefsLoaded) {
      return const LoadingState(hint: '正在读取背诵进度…');
    }
    final wordsAsync = ref.watch(vocabQueryProvider(''));
    final progressAsync = ref.watch(vocabProgressProvider);
    final dueAsync = ref.watch(vocabDueProvider);
    return wordsAsync.when(
      loading: () => const LoadingState(hint: '正在加载词库…'),
      error: (e, _) => EmptyState(icon: Icons.error_outline, title: '词库加载失败：$e'),
      data: (words) => progressAsync.when(
        loading: () => const LoadingState(hint: '正在读取背诵进度…'),
        error: (e, _) => EmptyState(icon: Icons.error_outline, title: '进度加载失败：$e'),
        data: (progress) => _ReciteView(
          key: ValueKey('${_orderSeed}_$_shuffle'),
          words: words,
          progress: progress,
          dueIds: dueAsync.valueOrNull ?? const <int>{},
          lastWordId: _lastWordId,
          orderSeed: _orderSeed,
          shuffle: _shuffle,
          onShuffle: _setShuffle,
          onPage: (id) async {
            await _saveLastWord(id);
            await ref.read(vocabRepositoryProvider).markSeen(id);
          },
          onMark: (id, known) async {
            await ref.read(vocabRepositoryProvider).markWord(id, known: known);
          },
          onClear: (id) async {
            await ref.read(vocabRepositoryProvider).clearWord(id);
          },
          onExit: () {
            ref.invalidate(vocabProgressProvider);
            setState(() => _reciteMode = false);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wordsAsync = ref.watch(vocabQueryProvider(_query));
    final progress = ref.watch(vocabProgressProvider).valueOrNull ??
        const <int, int>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('机械英语与翻译'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: ToggleButtons(
                isSelected: [!_reciteMode, _reciteMode],
                onPressed: (i) {
                  if (i == 1) ref.invalidate(vocabProgressProvider);
                  setState(() {
                    _reciteMode = i == 1;
                    _revealed.clear();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 32),
                textStyle: Theme.of(context).textTheme.labelSmall,
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('浏览'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('背诵'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _reciteMode ? _buildRecite(ref) : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.translate),
                hintText: '中英双向搜索：如 bearing / 轴承',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          // A-Z 首字母快捷导航
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: const Text('全部', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    selected: _letter == null,
                    onSelected: (_) => setState(() => _letter = null),
                  ),
                ),
                for (final L in _letters)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(L, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      selected: _letter == L,
                      onSelected: (_) => setState(() => _letter = L),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final entry in const [
                  ('all', '全部'),
                  ('new', '未背'),
                  ('weak', '还不熟'),
                  ('known', '已背'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(entry.$2,
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      selected: _statusFilter == entry.$1,
                      onSelected: (_) =>
                          setState(() => _statusFilter = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _reciteMode ? '背诵模式：点击卡片显示释义' : '共 586 词 · 离线 FTS 全文检索 · A-Z 快捷导航',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(
            child: wordsAsync.when(
              loading: () => const LoadingState(hint: '正在检索词库…'),
              error: (e, _) =>
                  EmptyState(icon: Icons.error_outline, title: '检索失败：$e'),
              data: (words) {
                var list = words;
                if (_letter != null) {
                  list = words
                      .where((w) =>
                          w.en.toUpperCase().startsWith(_letter!))
                      .toList();
                }
                if (_statusFilter == 'known') {
                  list = list.where((w) => progress[w.id] == 2).toList();
                } else if (_statusFilter == 'weak') {
                  list = list.where((w) => progress[w.id] == 1).toList();
                } else if (_statusFilter == 'new') {
                  list = list.where((w) => (progress[w.id] ?? 0) == 0).toList();
                }
                if (_query.isNotEmpty && list.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: '没有匹配“$_query”的词条',
                    subtitle: _letter == null
                        ? '中英均可检索；也可点 A-Z 浏览'
                        : '字母 $_letter 下无匹配，试试“全部”',
                  );
                }
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.translate,
                    title: '该字母暂无词条',
                    subtitle: '点“全部”查看完整词库',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => FadeIn(
                    delay: (i % 10) * 15,
                    child: _WordCard(
                      word: list[i],
                      status: progress[list[i].id] ?? 0,
                      recite: _reciteMode,
                      revealed: _revealed.contains(list[i].id),
                      onToggle: () => setState(() {
                        final id = list[i].id;
                        _revealed.contains(id)
                            ? _revealed.remove(id)
                            : _revealed.add(id);
                      }),
                      onClear: () => _markBrowse(list[i].id, null),
                      onKnown: () => _markBrowse(list[i].id, true),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReciteView extends StatefulWidget {
  const _ReciteView({
    super.key,
    required this.words,
    required this.progress,
    required this.dueIds,
    required this.lastWordId,
    required this.orderSeed,
    required this.shuffle,
    required this.onShuffle,
    required this.onPage,
    required this.onMark,
    required this.onClear,
    required this.onExit,
  });

  final List<VocabWord> words;
  final Map<int, int> progress;
  final Set<int> dueIds;
  final int? lastWordId;
  final int orderSeed;
  final bool shuffle;
  final Future<void> Function(bool) onShuffle;
  final Future<void> Function(int) onPage;
  final Future<void> Function(int, bool) onMark;
  final Future<void> Function(int) onClear;
  final VoidCallback onExit;

  @override
  State<_ReciteView> createState() => _ReciteViewState();
}

class _ReciteViewState extends State<_ReciteView> {
  late List<VocabWord> _queue;
  late Map<int, int> _status;
  late Set<int> _dueIds;
  late PageController _controller;
  int _index = 0;
  bool _revealed = false;
  bool _finished = false;
  bool _onlyWeak = false;

  int _score(int id) => (id * 9301 + widget.orderSeed * 49297) % 233280;

  List<VocabWord> _makeQueue() {
    var list = [
      for (final w in widget.words)
        if (_status[w.id] != 2 || _dueIds.contains(w.id)) w,
    ];
    if (_onlyWeak) {
      list = list.where((w) => _status[w.id] == 1).toList();
    }
    if (widget.shuffle) {
      list.sort((a, b) => _score(a.id).compareTo(_score(b.id)));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _status = Map<int, int>.from(widget.progress);
    _dueIds = Set<int>.from(widget.dueIds);
    _queue = _makeQueue();
    final last = widget.lastWordId;
    final found = last == null ? -1 : _queue.indexWhere((w) => w.id == last);
    _index = found >= 0 ? found : 0;
    _finished = _queue.isEmpty;
    _controller = PageController(initialPage: _index);
    if (_queue.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPage(_queue[_index].id);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _mark(bool known) async {
    if (_queue.isEmpty) return;
    final word = _queue[_index];
    setState(() {
      _status[word.id] = known ? 2 : 1;
      if (known) _dueIds.remove(word.id);
      _revealed = false;
    });
    await widget.onMark(word.id, known);
    if (!mounted) return;
    if (known) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已背：${word.en}'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            await widget.onClear(word.id);
            if (mounted) {
              setState(() => _status[word.id] = 0);
            }
          },
        ),
      ));
    }
    if (_index < _queue.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      setState(() => _finished = true);
    }
  }

  void _restart() {
    setState(() {
      _queue = _makeQueue();
      _index = 0;
      _finished = _queue.isEmpty;
      _revealed = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(0);
    });
  }

  void _toggleWeak(bool value) {
    setState(() {
      _onlyWeak = value;
      _queue = _makeQueue();
      _index = 0;
      _finished = _queue.isEmpty;
      _revealed = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) _controller.jumpToPage(0);
    });
  }

  Future<void> _spelling(VocabWord word) async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('拼写检查'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '看中文，拼英文',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('检查'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null || !mounted) return;
    final ok = input.trim().toLowerCase() == word.en.trim().toLowerCase();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '拼写正确：${word.en}' : '再想想：正确答案是 ${word.en}'),
      backgroundColor: ok ? Colors.green.shade700 : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final known = _status.values.where((v) => v == 2).length;
    if (_finished) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration_outlined, size: 44),
              const SizedBox(height: 12),
              Text('本轮背完了',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('已背 $known / ${widget.words.length} 词',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _restart,
                child: const Text('再来一轮未背的'),
              ),
              TextButton(onPressed: widget.onExit, child: const Text('去浏览')),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '第 ${_index + 1}/${_queue.length} 条 · 已背 $known/${widget.words.length} · 待复习 ${_dueIds.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              FilterChip(
                label: const Text('还不熟', style: TextStyle(fontSize: 10)),
                selected: _onlyWeak,
                visualDensity: VisualDensity.compact,
                onSelected: _toggleWeak,
              ),
              const SizedBox(width: 4),
              const Text('乱序', style: TextStyle(fontSize: 11)),
              Switch(
                value: widget.shuffle,
                onChanged: (v) => widget.onShuffle(v),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _queue.length,
            onPageChanged: (i) {
              setState(() {
                _index = i;
                _revealed = false;
              });
              widget.onPage(_queue[i].id);
            },
            itemBuilder: (context, i) {
              final word = _queue[i];
              final status = _status[word.id] ?? 0;
              return Card(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: InkWell(
                  onTap: () => setState(() => _revealed = !_revealed),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(word.category,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall),
                            ),
                            const Spacer(),
                            if (status == 1)
                              const Text('还不熟',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.orange)),
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 28),
                                Text(word.en,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold)),
                                const SizedBox(height: 18),
                                if (_revealed) ...[
                                  Text(word.zh,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary)),
                                  if (word.example != null &&
                                      word.example!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(word.example!,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                  ],
                                ] else
                                  Text('点击卡片显示释义',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => _revealed = !_revealed),
                              child: Text(_revealed ? '收起释义' : '显示释义'),
                            ),
                            TextButton.icon(
                              onPressed: () => _spelling(word),
                              icon: const Icon(Icons.keyboard, size: 16),
                              label: const Text('拼写'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _mark(false),
                                child: const Text('还不熟'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _mark(true),
                                child: const Text('已背'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.word,
    required this.status,
    required this.recite,
    required this.revealed,
    required this.onToggle,
    required this.onClear,
    required this.onKnown,
  });

  final VocabWord word;
  final int status;
  final bool recite;
  final bool revealed;
  final VoidCallback onToggle;
  final VoidCallback onClear;
  final VoidCallback onKnown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showZh = !recite || revealed;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: recite ? onToggle : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(word.en,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  if (status == 2 || status == 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 2
                              ? scheme.primaryContainer
                              : scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(status == 2 ? '已背' : '还不熟',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(fontSize: 10)),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      word.category,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              showZh
                  ? Text(word.zh,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.primary))
                  : Text('· · · · · ·（点击显示释义）',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant, letterSpacing: 2)),
              if (showZh && word.example != null && word.example!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(word.example!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
              ],
              if (!recite)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 2)
                      TextButton.icon(
                        onPressed: onClear,
                        icon: const Icon(Icons.restart_alt, size: 15),
                        label: const Text('标为未背',
                            style: TextStyle(fontSize: 11)),
                      )
                    else
                      TextButton.icon(
                        onPressed: onKnown,
                        icon: const Icon(Icons.check, size: 15),
                        label: const Text('标为已背',
                            style: TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}