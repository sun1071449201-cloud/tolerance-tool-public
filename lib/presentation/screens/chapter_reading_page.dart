import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../../domain/models/chapter_learning.dart';
import '../state/book_providers.dart';
import '../widgets/eng_sketches.dart';
import '../widgets/reader_markdown.dart';
import '../widgets/states.dart';
import 'bookmarks_manage_page.dart';
import 'global_search_page.dart';
import 'quick_ref_detail_page.dart';
import 'fit_solver_page.dart';
import 'gdnt_panel_page.dart';
import 'tools/bolt_torque_page.dart';
import 'tools/metrology_page.dart';
import 'tools/tolerance_chain_page.dart';
import 'tools/unit_convert_page.dart';
import 'tools/weight_calc_page.dart';

/// 阅读页：类书籍排版（Markdown 分段渲染），上下滚动，全局字号调整，
/// 上一章/下一章；支持锚点/书签精准定位并高亮；自动记忆阅读进度；
/// 分段可添加书签（带备注）；章节末尾可标记已读。
class ChapterReadingPage extends ConsumerWidget {
  const ChapterReadingPage({
    super.key,
    required this.chapterKey,
    this.anchor,
    this.jumpSegment,
    this.searchQuery,
  });

  final String chapterKey;

  /// 节号锚点（如 "1.2.2"），非空时加载后自动滚动并高亮该节。
  final String? anchor;

  /// 书签跳转：直接定位到分段下标。
  final int? jumpSegment;

  /// 全局搜索命中的关键词，用于显示命中提示。
  final String? searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(fontScaleControllerProvider);
    final key = chapterKey.trim();
    final contentAsync = ref.watch(chapterContentProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: contentAsync.whenOrNull(
              data: (c) => Text(c.chapterTitle),
            ) ??
            const Text('阅读'),
        actions: [
          PopupMenuButton<FontScale>(
            icon: const Icon(Icons.format_size),
            tooltip: '字号',
            onSelected: (s) =>
                ref.read(fontScaleControllerProvider.notifier).choose(s),
            itemBuilder: (_) => [
              for (final s in FontScale.values)
                PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      Icon(
                        s == scale ? Icons.check : Icons.circle_outlined,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text('${s.label}号字'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: '书签列表',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookmarksManagePage())),
          ),
        ],
      ),
      body: key.isEmpty
          ? _ChapterLoadError(chapterKey: key)
          : contentAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ChapterLoadError(
                chapterKey: key,
                detail: e.toString(),
              ),
              data: (content) => _ReadingView(
                content: content,
                anchor: anchor,
                jumpSegment: jumpSegment,
                searchQuery: searchQuery,
                chapterKey: key,
              ),
            ),
    );
  }
}

/// 章节找不到时的友好兜底：不把异常直接甩给用户，也不让页面红屏。
class _ChapterLoadError extends StatelessWidget {
  const _ChapterLoadError({required this.chapterKey, this.detail});

  final String chapterKey;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    if (detail != null) {
      debugPrint('章节加载失败：$detail');
    }
    final key = chapterKey.trim();
    return EmptyState(
      icon: Icons.menu_book_outlined,
      title: '这篇内容暂时没找到',
      subtitle: key.isEmpty
          ? '这条知识点没有带上章节编号，可能指向了旧版书籍。'
          : '章节编号：$key\n可能是书籍数据没更新，或这条知识点指向了旧章节。',
      action: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('返回'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const GlobalSearchPage(),
            )),
            icon: const Icon(Icons.search, size: 16),
            label: const Text('全局搜索'),
          ),
        ],
      ),
    );
  }
}

class _ReadingView extends ConsumerStatefulWidget {
  const _ReadingView({
    required this.content,
    required this.chapterKey,
    this.anchor,
    this.jumpSegment,
    this.searchQuery,
  });

  final ChapterContent content;
  final String chapterKey;
  final String? anchor;
  final int? jumpSegment;
  final String? searchQuery;

  @override
  ConsumerState<_ReadingView> createState() => _ReadingViewState();
}

class _ReadingViewState extends ConsumerState<_ReadingView> {
  final _scrollController = ScrollController();
  final _segmentKeys = <int, GlobalKey>{};
  int? _highlightIndex;
  Timer? _highlightTimer;
  Timer? _saveDebounce;
  bool _restored = false;
  bool _jumpNoticeShown = false;
  // 锚点/书签跳转只执行一次；用户之后手动滚动不能被定时器或 rebuild 拉回去。
  bool _initialJumpHandled = false;
  int _visibleCount = 40;
  bool _learningSeenMarked = false;

  void _notifyJumpMiss(String message) {
    if (_jumpNoticeShown) return;
    _jumpNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  GlobalKey _keyFor(int index) => _segmentKeys.putIfAbsent(index, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _ReadingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同一页面被换成不同锚点/书签时，允许新目标再跳一次。
    if (oldWidget.anchor != widget.anchor ||
        oldWidget.jumpSegment != widget.jumpSegment) {
      _initialJumpHandled = false;
      _jumpNoticeShown = false;
    }
  }

  void _onScroll() {
    // 滚动停稳（800ms 无滚动）后保存阅读进度。
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || !_scrollController.hasClients) return;
      ref.read(userDataRepositoryProvider).saveProgress(
            bookId: widget.content.bookId,
            chapterKey: widget.content.chapterKey,
            offsetPx: _scrollController.offset,
          );
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (_scrollController.hasClients) {
      // 离开页面也保存一次最终位置。
      ref.read(userDataRepositoryProvider).saveProgress(
            bookId: widget.content.bookId,
            chapterKey: widget.content.chapterKey,
            offsetPx: _scrollController.offset,
          );
    }
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _highlight(int index) {
    if (index >= _visibleCount) {
      setState(() => _visibleCount = index + 20);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _keyFor(index).currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.06,
        );
      }
      setState(() => _highlightIndex = index);
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightIndex = null);
      });
    });
  }

  void _showToc() {
    final content = widget.content;
    final items = <Widget>[];
    for (var i = 0; i < content.segments.length; i++) {
      final heading = content.segments[i].heading;
      if (heading == null || heading.trim().isEmpty) continue;
      items.add(ListTile(
        dense: true,
        leading: const Icon(Icons.article_outlined, size: 18),
        title: Text(heading),
        onTap: () {
          Navigator.of(context).pop();
          _highlight(i);
        },
      ));
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('本章没有可跳转的小节'),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text('本章目录',
                        style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                  ...items,
                ],
              ),
      ),
    );
  }

  String? _anchorForSegment(int segmentIndex) {
    final h = widget.content.segments[segmentIndex].heading?.trim();
    if (h == null || h.isEmpty) return null;
    final m = RegExp(r'^([0-9]+(?:\.[0-9]+)*)').firstMatch(h);
    return m?.group(1) ?? h;
  }

  Future<void> _addBookmark(int segmentIndex) async {
    final content = widget.content;
    final plain = content.segments[segmentIndex].bodyMd
        .replaceAll(RegExp(r'[#*|>`\n]'), ' ')
        .trim();
    final excerpt =
        plain.length <= 30 ? plain : '${plain.substring(0, 30)}…';
    final noteController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加书签'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(excerpt, style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存书签')),
        ],
      ),
    );
    if (saved == true && mounted) {
      await ref.read(userDataRepositoryProvider).addBookmark(
            bookId: content.bookId,
            chapterKey: content.chapterKey,
            segmentIndex: segmentIndex,
            excerpt: excerpt,
            note: noteController.text.isEmpty ? null : noteController.text,
            anchor: _anchorForSegment(segmentIndex),
          );
      ref.invalidate(bookmarksForChapterProvider(content.chapterKey));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('书签已保存')));
      }
    }
  }

  Future<void> _toggleRead() async {
    final marks = ref.read(readMarksProvider).valueOrNull ?? {};
    final isRead = marks[widget.content.chapterKey] ?? false;
    await ref
        .read(userDataRepositoryProvider)
        .setRead(widget.content.chapterKey, isRead: !isRead);
    ref.invalidate(readMarksProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(!isRead ? '已标记为已读' : '已恢复为未读'),
      ));
    }
  }

  /// 搜索时把关键词加粗（跳过代码块/行内代码），保留 Markdown 结构。
  String _highlightMarkdown(String body) {
    final q = (widget.searchQuery ?? '').trim();
    if (q.isEmpty) return body;
    final re = RegExp(RegExp.escape(q), caseSensitive: false);
    final lines = body.split('\n');
    var inFence = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        continue;
      }
      if (inFence || line.trim().isEmpty) continue;
      final parts = line.split('`');
      for (var j = 0; j < parts.length; j += 2) {
        parts[j] = parts[j].replaceAllMapped(
          re,
          (m) => '**${m.group(0)}**',
        );
      }
      lines[i] = parts.join('`');
    }
    return lines.join('\n');
  }

  String _searchHitLabel() {
    final q = (widget.searchQuery ?? '').trim();
    final idx = _highlightIndex;
    if (idx == null || idx < 0 || idx >= widget.content.segments.length) {
      return '搜索：$q · 已定位到命中章节';
    }
    final body = widget.content.segments[idx].bodyMd.toLowerCase();
    final needle = q.toLowerCase();
    var count = 0;
    var from = 0;
    while (needle.isNotEmpty) {
      final at = body.indexOf(needle, from);
      if (at < 0) break;
      count++;
      from = at + needle.length;
    }
    return '搜索：$q${count > 0 ? ' · 本段命中 $count 处' : ' · 已定位到命中段落'}';
  }

  Widget? _toolPage(String id) {
    switch (id) {
      case 'fit':
        return const FitSolverPage();
      case 'chain':
        return const ToleranceChainPage();
      case 'cpk':
        return const MetrologyPage();
      case 'weight':
        return const WeightCalcPage();
      case 'unit':
        return const UnitConvertPage();
      case 'torque':
        return const BoltTorquePage();
      case 'gdnt':
        return const GdntPanelPage();
      default:
        return null;
    }
  }

  String _toolLabel(String id) {
    switch (id) {
      case 'fit':
        return '配合反选';
      case 'chain':
        return '尺寸链';
      case 'cpk':
        return 'CPK/计量';
      case 'weight':
        return '重量';
      case 'unit':
        return '单位换算';
      case 'torque':
        return '螺栓扭矩';
      case 'gdnt':
        return 'GD&T 图解';
      default:
        return id;
    }
  }

  void _openTool(BuildContext context, String id) {
    final page = _toolPage(id);
    if (page == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _markLearning(int status, {int? score}) async {
    await ref.read(userDataRepositoryProvider).markChapterLearning(
          widget.content.chapterKey,
          status,
          score: score,
        );
    ref.invalidate(chapterLearningProvider);
  }

  Future<void> _openQuiz(ChapterLearning learning) async {
    if (learning.quiz.isEmpty) return;
    final answers = List<int?>.filled(learning.quiz.length, null);
    var submitted = false;
    var score = 0;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('本章自测（${learning.quiz.length} 题）'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < learning.quiz.length; i++) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Text(
                          '${i + 1}. ${learning.quiz[i].question}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    for (var j = 0;
                        j < learning.quiz[i].options.length;
                        j++)
                      RadioListTile<int>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(learning.quiz[i].options[j],
                            style: const TextStyle(fontSize: 13)),
                        value: j,
                        groupValue: answers[i],
                        onChanged: submitted
                            ? null
                            : (v) => setLocal(() => answers[i] = v),
                      ),
                    if (submitted)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            answers[i] == learning.quiz[i].answer
                                ? '✓ 正确：${learning.quiz[i].explanation}'
                                : '✗ 正确答案：${learning.quiz[i].options[learning.quiz[i].answer]}。${learning.quiz[i].explanation}',
                            style: TextStyle(
                              fontSize: 12,
                              color: answers[i] == learning.quiz[i].answer
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                  ],
                  if (submitted)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('得分：$score / ${learning.quiz.length}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
            if (!submitted)
              FilledButton(
                onPressed: answers.every((a) => a != null)
                    ? () {
                        var s = 0;
                        for (var i = 0; i < learning.quiz.length; i++) {
                          if (answers[i] == learning.quiz[i].answer) s++;
                        }
                        setLocal(() {
                          score = s;
                          submitted = true;
                        });
                      }
                    : null,
                child: const Text('交卷'),
              )
            else
              FilledButton(
                onPressed: () => Navigator.pop(ctx, score),
                child: const Text('完成'),
              ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final passed = result * 3 >= learning.quiz.length * 2;
    await _markLearning(passed ? 2 : 1, score: result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(passed
          ? '自测通过：$result/${learning.quiz.length}，本章已标记“掌握”'
          : '得分：$result/${learning.quiz.length}，再回看一遍本章'),
    ));
  }

  Widget _statusChip(int status) {
    final label = status == 2 ? '已掌握' : (status == 1 ? '看过' : '未学');
    final color = status == 2
        ? Colors.green.shade700
        : (status == 1 ? Colors.blue.shade700 : Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.bold)),
    );
  }

  List<Widget> _knowledgeChips(BuildContext context, ChapterContent content) {
    return [
      for (var i = 0; i < content.segments.length; i++)
        if ((content.segments[i].heading ?? '').trim().isNotEmpty)
          ActionChip(
            label: Text(content.segments[i].heading!.trim(),
                style: const TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
            onPressed: () => _highlight(i),
          ),
    ];
  }

  Widget _learningCard(BuildContext context, ChapterLearning learning,
      int status, ChapterContent content) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: scheme.primaryContainer.withOpacity(0.28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined, size: 18),
                const SizedBox(width: 6),
                const Text('本章速览',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _statusChip(status),
                const Spacer(),
                if (learning.quiz.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _openQuiz(learning),
                    icon: const Icon(Icons.quiz_outlined, size: 16),
                    label: const Text('自测',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            for (final s in learning.summary)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('• $s',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.45)),
              ),
            if (learning.counterexample.isNotEmpty ||
                learning.boundaries.isNotEmpty ||
                learning.checklist.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 6),
                title: const Text('适用边界 · 反例 · 检查清单',
                    style: TextStyle(fontSize: 12.5)),
                children: [
                  if (learning.boundaries.isNotEmpty)
                    _miniSection(context, '适用边界', learning.boundaries),
                  if (learning.counterexample.isNotEmpty)
                    _miniSection(
                        context, '反例', [learning.counterexample]),
                  if (learning.checklist.isNotEmpty)
                    _miniSection(context, '现场检查清单', learning.checklist),
                ],
              ),
            if (learning.standard.isNotEmpty ||
                learning.reviewedAt.isNotEmpty ||
                learning.canonical)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(
                  [
                    if (learning.canonical) '主源章节',
                    if (learning.standard.isNotEmpty) learning.standard,
                    if (learning.reviewedAt.isNotEmpty)
                      '复核：${learning.reviewedAt}',
                  ].join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            if (learning.seeAlso.isNotEmpty || learning.quickRefs.isNotEmpty || learning.relatedTools.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  const Text('参见：',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                  for (final key in learning.seeAlso)
                    ActionChip(
                      label: Text(key.split('.').last,
                          style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                ChapterReadingPage(chapterKey: key)),
                      ),
                    ),
                  for (final id in learning.quickRefs)
                    ActionChip(
                      label: Text('速查：$id',
                          style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => QuickRefDetailPage(refId: id)),
                      ),
                    ),
                  for (final id in learning.relatedTools)
                    ActionChip(
                      label: Text('工具：${_toolLabel(id)}',
                          style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openTool(context, id),
                    ),
                ],
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              title: Text('本章知识卡（${_knowledgeChips(context, content).length}）',
                  style: const TextStyle(fontSize: 12.5)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _knowledgeChips(context, content),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniSection(
      BuildContext context, String title, List<String> items) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.bold)),
            for (final s in items)
              Text('· $s',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _knowledgeOnlyCard(BuildContext context, ChapterContent content) {
    final chips = _knowledgeChips(context, content);
    if (chips.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text('本章知识卡（${chips.length}）',
            style: const TextStyle(fontSize: 12.5)),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 6, runSpacing: 4, children: chips),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = ref.watch(fontScaleControllerProvider);
    final content = widget.content;
    final learning = ref.watch(bookLearningProvider).valueOrNull?[content.chapterKey];
    final learningStatus =
        ref.watch(chapterLearningProvider).valueOrNull?[content.chapterKey] ?? 0;
    if (learning != null && learningStatus == 0 && !_learningSeenMarked) {
      _learningSeenMarked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markLearning(1);
      });
    }
    final bookmarksAsync =
        ref.watch(bookmarksForChapterProvider(content.chapterKey));
    final marks = ref.watch(readMarksProvider).valueOrNull ?? {};
    final isRead = marks[content.chapterKey] ?? false;

    // 锚点/书签跳转定位：所有入口先做范围检查，找不到就明确告诉用户，
    // 不再让 null / 越界值一路传到渲染层。
    final requestedAnchor = widget.anchor?.trim();
    final anchorTarget = content.resolveAnchor(requestedAnchor);
    final bookmarkSegment = widget.jumpSegment;
    final safeBookmarkSegment = bookmarkSegment != null &&
            bookmarkSegment >= 0 &&
            bookmarkSegment < content.segments.length
        ? bookmarkSegment
        : null;
    if (requestedAnchor != null &&
        requestedAnchor.isNotEmpty &&
        anchorTarget == null) {
      _notifyJumpMiss('本章没有找到“$requestedAnchor”节，已为你打开本章，可继续向下找');
    } else if (bookmarkSegment != null && safeBookmarkSegment == null) {
      _notifyJumpMiss('这条书签对应的段落已变化，已为你打开本章开头');
    }
    final jumpTarget = anchorTarget ?? safeBookmarkSegment;
    if (!_initialJumpHandled && jumpTarget != null) {
      _initialJumpHandled = true;
      final target = jumpTarget;
      WidgetsBinding.instance.addPostFrameCallback((_) => _highlight(target));
    }

    // 阅读进度恢复：无锚点/书签跳转时，回到上次滚动位置。
    if (jumpTarget == null && !_restored) {
      final saved =
          ref.watch(chapterProgressProvider('${content.bookId}|${content.chapterKey}'));
      saved.whenData((offset) {
        if (!_restored && offset > 40) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                !_restored &&
                _scrollController.hasClients &&
                _scrollController.offset < 10) {
              _scrollController.jumpTo(offset.clamp(
                  0.0, _scrollController.position.maxScrollExtent));
            }
            _restored = true;
          });
        } else {
          _restored = true;
        }
      });
    }

    final prevKey = content.prevKey ?? '';
    final nextKey = content.nextKey ?? '';

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          content.bookTitle,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          content.chapterTitle,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold, height: 1.3),
        ),
        const SizedBox(height: 12),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _showToc,
            icon: const Icon(Icons.toc, size: 18),
            label: const Text('本章目录'),
          ),
        ),
        if ((widget.searchQuery ?? '').trim().isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _searchHitLabel(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        if (learning != null)
          _learningCard(context, learning, learningStatus, content)
        else
          _knowledgeOnlyCard(context, content),
        // 划词搜索：长按选中文字 → 上下文菜单「词典查询 / 全局搜索」
        SelectionArea(
          contextMenuBuilder: (context, selectableRegion) =>
              _SelectionContextMenu(
            selectableRegion: selectableRegion,
          ),
          child: Column(
            children: [
              for (var i = 0;
                  i < content.segments.length && i < _visibleCount;
                  i++)
                _segment(
                  context: context,
                  index: i,
                  bodyMd: _highlightMarkdown(content.segments[i].bodyMd),
                  scale: scale,
                  highlighted: i == _highlightIndex,
                  bookmarked: bookmarksAsync.valueOrNull
                          ?.any((b) => b.segmentIndex == i) ??
                      false,
                  onBookmark: () => _addBookmark(i),
                ),
              if (_visibleCount < content.segments.length)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _visibleCount = _visibleCount + 40 >
                              content.segments.length
                          ? content.segments.length
                          : _visibleCount + 40;
                    }),
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text(
                        '继续加载（剩余 ${content.segments.length - _visibleCount} 段）'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: _toggleRead,
          icon: Icon(isRead ? Icons.remove_done : Icons.done_all, size: 18),
          label: Text(isRead ? '标记为未读' : '标记为已读'),
        ),
        const SizedBox(height: 16),
        Divider(color: Theme.of(context).colorScheme.outlineVariant),
        Row(
          children: [
            Expanded(
              child: prevKey.isEmpty
                  ? const SizedBox()
                  : FilledButton.tonalIcon(
                      onPressed: () => _open(context, prevKey),
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('上一章'),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: nextKey.isEmpty
                  ? const SizedBox()
                  : FilledButton.icon(
                      onPressed: () => _open(context, nextKey),
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('下一章'),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _segment({
    required BuildContext context,
    required int index,
    required String bodyMd,
    required FontScale scale,
    required bool highlighted,
    required bool bookmarked,
    required VoidCallback onBookmark,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: _keyFor(index),
      decoration: highlighted
          ? BoxDecoration(
              color: scheme.primaryContainer.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.primary, width: 1.2),
            )
          : null,
      padding: highlighted
          ? const EdgeInsets.all(10)
          : const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: Stack(
        children: [
          MarkdownBody(
            data: bodyMd,
            softLineBreak: true,
            extensionSet: readerMarkdownExtensions,
            styleSheet: _bookStyleSheet(context, scale),
            builders: {'code': DiagramCodeBuilder()},
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '添加书签',
              icon: Icon(
                bookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 16,
                color: bookmarked ? scheme.primary : scheme.onSurfaceVariant.withOpacity(0.5),
              ),
              onPressed: onBookmark,
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, String key) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ChapterReadingPage(chapterKey: key),
    ));
  }
}

/// 划词上下文菜单：在系统选择工具基础上，提供「查词典」「全局搜索」「复制」。
/// 取词方式：copySelection 到剪贴板后读取（跨版本稳定）。
class _SelectionContextMenu extends StatelessWidget {
  const _SelectionContextMenu({required this.selectableRegion});

  final SelectableRegionState selectableRegion;

  Future<String?> _grabText() async {
    // copySelection 在 3.24 仍是取选中文本的唯一稳定途径（官方仅提示 deprecated）。
    // ignore: deprecated_member_use
    selectableRegion.copySelection(SelectionChangedCause.toolbar);
    final data = await Clipboard.getData('text/plain');
    return data?.text?.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegion.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: '查词典',
          onPressed: () async {
            final text = await _grabText();
            selectableRegion.hideToolbar();
            if (text == null || text.isEmpty || !context.mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _VocabLookupPage(query: text),
            ));
          },
        ),
        ContextMenuButtonItem(
          label: '全局搜索',
          onPressed: () async {
            final text = await _grabText();
            selectableRegion.hideToolbar();
            if (text == null || text.isEmpty || !context.mounted) return;
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GlobalSearchPage(initialQuery: text),
            ));
          },
        ),
        ContextMenuButtonItem(
          label: '复制',
          onPressed: () {
            // ignore: deprecated_member_use
            selectableRegion.copySelection(SelectionChangedCause.toolbar);
            selectableRegion.hideToolbar();
          },
        ),
      ],
    );
  }
}

/// 划词 → 词典查询结果页（机械英语词库 FTS 检索）。
class _VocabLookupPage extends ConsumerWidget {
  const _VocabLookupPage({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(vocabQueryProvider(query));
    return Scaffold(
      appBar: AppBar(title: Text('词典：$query')),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('查询失败：$e')),
        data: (words) => words.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('词库中没有匹配词条'),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  GlobalSearchPage(initialQuery: query))),
                      child: const Text('改用全局搜索'),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (final w in words)
                    ListTile(
                      title: Text(w.en,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text(w.zh),
                      trailing: w.example == null
                          ? null
                          : const Icon(Icons.chat_bubble_outline, size: 16),
                      onTap: w.example == null
                          ? null
                          : () => showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(w.en),
                                  content: Text('${w.zh}\n\n${w.example}'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('关闭'))
                                  ],
                                ),
                              ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// 书籍排版：随字号档位整体缩放，正文 1.75 倍行距，引用块带左侧色条。
MarkdownStyleSheet _bookStyleSheet(BuildContext context, FontScale scale) {
  final theme = Theme.of(context);
  final s = scale.bodySize / 17;
  final base = theme.textTheme.bodyLarge?.copyWith(
        fontSize: scale.bodySize,
        height: 1.85, // 呼吸感：行距略增
      ) ??
      TextStyle(fontSize: scale.bodySize, height: 1.85);
  final codeStyle = theme.textTheme.bodyMedium?.copyWith(
        fontSize: scale.bodySize * 0.85,
        height: 1.5,
        fontFamily: 'monospace',
      ) ??
      TextStyle(fontSize: scale.bodySize * 0.85);

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: base,
    listBullet: base,
    h1: theme.textTheme.titleLarge?.copyWith(
        fontSize: 22 * s, height: 1.4, fontWeight: FontWeight.bold),
    h2: theme.textTheme.titleMedium?.copyWith(
        fontSize: 19 * s, height: 1.45, fontWeight: FontWeight.bold),
    h3: theme.textTheme.titleSmall?.copyWith(
        fontSize: 17 * s, height: 1.5, fontWeight: FontWeight.bold),
    h4: base.copyWith(fontWeight: FontWeight.bold),
    blockquote: base.copyWith(
        color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
    blockquoteDecoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: theme.colorScheme.primary, width: 3),
      ),
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
    code: codeStyle.copyWith(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    ),
    codeblockDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    codeblockPadding: const EdgeInsets.all(10),
    tableHead:
        base.copyWith(fontWeight: FontWeight.bold, fontSize: scale.bodySize * 0.88),
    tableBody: base.copyWith(fontSize: scale.bodySize * 0.88, height: 1.4),
    tableBorder:
        TableBorder.all(color: theme.colorScheme.outlineVariant, width: 1),
    // 固定列宽会触发 flutter_markdown 的横向滚动包裹，宽表在手机上可左右滑。
    tableColumnWidth: FixedColumnWidth(
        MediaQuery.sizeOf(context).width < 380
            ? 96
            : (MediaQuery.sizeOf(context).width > 700 ? 150 : 112)),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
    ),
  );
}