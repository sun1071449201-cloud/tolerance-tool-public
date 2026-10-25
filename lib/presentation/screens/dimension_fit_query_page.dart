import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../domain/models/tolerance_models.dart';
import '../state/providers.dart';
import '../state/book_providers.dart';
import '../widgets/daily_tips_section.dart';
import '../widgets/home_learning_cards.dart';
import '../widgets/favorite_star_button.dart';
import '../widgets/favorites_dashboard.dart';
import '../widgets/home_quick_cards.dart';
import '../widgets/history_chips.dart';
import '../widgets/knowledge_tip_card.dart';
import '../widgets/tolerance_zone_chart.dart';
import 'fit_solver_page.dart';
import 'gdnt_panel_page.dart';
import 'global_search_page.dart';
import 'quick_ref_detail_page.dart';
import 'tools/tools_hub_page.dart';

import '../../data/database/app_database.dart' show QuickRefItem;

/// 里程碑 1 主页面：尺寸公差与配合查询。
class DimensionFitQueryPage extends ConsumerStatefulWidget {
  const DimensionFitQueryPage({super.key});

  @override
  ConsumerState<DimensionFitQueryPage> createState() => _DimensionFitQueryPageState();
}

class _DimensionFitQueryPageState extends ConsumerState<DimensionFitQueryPage> {
  final _controller = TextEditingController(text: '⌀50 H7/g6');

  static const _examples = ['⌀50 H7/g6', '⌀30 H7/k6', '⌀50 H7/p6', '⌀20 H8/f7', '⌀50 H7'];

  /// 防止 pendingQuery 被 initState 与 ref.listen 双路径重复消费。
  bool _consumingPending = false;

  void _consumePending(String? pending) {
    if (pending == null || !mounted || _consumingPending) return;
    _consumingPending = true;
    _controller.text = pending;
    _query();
    ref.read(pendingQueryProvider.notifier).state = null;
    _consumingPending = false;
  }

  @override
  void initState() {
    super.initState();
    // 全局搜索页点“到查询页看公差带图”→ 预填并执行（首帧兜底）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePending(ref.read(pendingQueryProvider));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _query() {
    FocusScope.of(context).unfocus();
    ref.read(queryControllerProvider.notifier).query(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    // 全局搜索跳转预填：ref.listen 只能放在 build 顶层（Riverpod 断言要求）
    ref.listen<String?>(pendingQueryProvider, (prev, next) {
      _consumePending(next);
    });

    final state = ref.watch(queryControllerProvider);
    final ctx = ref.watch(standardContextProvider);

    // 智能联想：输入像 "M6"、"anodize"、"阳极" 等关键词时，提示速查条目
    final raw = _controller.text.trim();
    final suggestions = (raw.length >= 2 && raw.length <= 12)
        ? (ref.watch(quickRefQueryProvider(raw)).valueOrNull ?? const [])
            .take(3)
            .toList()
        : const <QuickRefItem>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('尺寸公差与配合查询'),
        actions: [
          IconButton(
            tooltip: '反选求解（推荐配合）',
            icon: const Icon(Icons.auto_fix_high),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FitSolverPage())),
          ),
          IconButton(
            tooltip: '全局搜索',
            icon: const Icon(Icons.travel_explore),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GlobalSearchPage())),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('标准族 ${ctx.family}', style: Theme.of(context).textTheme.labelMedium),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            HomeQuickCards(
              onOpenSolver: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FitSolverPage())),
              onOpenSearch: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GlobalSearchPage())),
              onOpenTools: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ToolsHubPage())),
              onOpenGdnt: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GdntPanelPage())),
            ),
            const SizedBox(height: 10),
            const HomeLearningCards(),
            const DailyTipsSection(),
            const SizedBox(height: 10),
            HistoryChips(onPick: (q) {
              _controller.text = q;
              _query();
            }),
            const SizedBox(height: 6),
            const FavoritesDashboard(),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: '基本尺寸 + 公差带代号',
                      hintText: '例如 ⌀50 H7/g6 或 50 H7/g6',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixText: _controller.text.startsWith('⌀') ? '' : '',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '插入直径符号',
                            icon: const Text('⌀',
                                style: TextStyle(fontSize: 18)),
                            onPressed: () {
                              final pos = _controller.selection.baseOffset;
                              final text = _controller.text;
                              final insertAt =
                                  pos < 0 ? text.length : pos.clamp(0, text.length);
                              final next =
                                  text.replaceRange(insertAt, insertAt, '⌀');
                              _controller.value = TextEditingValue(
                                text: next,
                                selection: TextSelection.collapsed(
                                    offset: insertAt + 1),
                              );
                            },
                          ),
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _controller.clear();
                              },
                            ),
                        ],
                      ),
                    ),
                    onSubmitted: (_) => _query(),
                    onChanged: (_) => setState(() {}), // 联想词随输入刷新
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _query, child: const Text('查询')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final e in _examples)
                  ActionChip(
                    label: Text(e),
                    onPressed: () {
                      _controller.text = e;
                      _query();
                    },
                  ),
              ],
            ),
            // 智能猜你想查
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.tips_and_updates_outlined,
                      size: 14, color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 4),
                  Text('猜你想查',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                              color: Theme.of(context).colorScheme.tertiary)),
                ],
              ),
              for (final s in suggestions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  leading: const Icon(Icons.grid_view, size: 16),
                  title: Text(s.title,
                      style: Theme.of(context).textTheme.bodySmall),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => QuickRefDetailPage(refId: s.refId),
                  )),
                ),
            ],
            const SizedBox(height: 8),
            _placeholderBanner(context),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            // 结果区平滑过渡：加载/出错/结果 三态淡入切换。
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: state.loading
                  ? const SizedBox.shrink(key: ValueKey('loading'))
                  : state.error != null
                      ? _errorCard(context, state.error!)
                      : state.result == null
                          ? const SizedBox.shrink(key: ValueKey('idle'))
                          : Column(
                              key: const ValueKey('result'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _headerCard(context, state.result!),
                                _deviationCard(context, state.result!),
                                _fitCard(context, state.result!),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            FavoriteStarButton(
                                              kind: 'tolerance',
                                              title: state
                                                  .result!.input.display,
                                              subtitle: state.result!.fitType
                                                      ?.label ??
                                                  '公差查询',
                                              targetKey: state
                                                  .result!.input.display,
                                            ),
                                          ],
                                        ),
                                        ToleranceZoneChart(
                                            result: state.result!),
                                      ],
                                    ),
                                  ),
                                ),
                                for (final tip in state.tips)
                                  KnowledgeTipCard(tip: tip),
                              ],
                            ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _placeholderBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = ref.watch(datasetModeProvider).valueOrNull ?? 'demo';
    final isStandard = mode == 'standard';
    final bg = isStandard ? scheme.primaryContainer : scheme.tertiaryContainer;
    final fg = isStandard ? scheme.onPrimaryContainer : scheme.onTertiaryContainer;
    final text = isStandard
        ? '当前数据集：标准库（已完成人工核对；IT1/IT2 按整数 µm 显示）。发现异常数值请反馈修正。'
        : '当前数据集：演示库——标准数值为占位/未完整核对（导入方法见 docs/标准库导入接口.md）。';
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isStandard ? Icons.verified_outlined : Icons.warning_amber_rounded,
                size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: fg)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    final lastQuery = _controller.text.trim();
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.menu_book, size: 14),
                  label: const Text('去《综合知识手册》搜原理'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GlobalSearchPage(
                        initialQuery: lastQuery.isEmpty ? null : lastQuery),
                  )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context, FitQueryResult r) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.input.display, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (r.fitType != null)
                  Chip(
                    label: Text(r.fitType!.label),
                    backgroundColor: scheme.secondaryContainer,
                    labelStyle: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                if (r.holeBasis)
                  const Chip(label: Text('基孔制')),
                if (r.shaftBasis) const Chip(label: Text('基轴制')),
                Chip(label: Text('尺寸段 ${r.stepBracket} mm')),
                Chip(label: Text('标准 ${r.standardUsed}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviationCard(BuildContext context, FitQueryResult r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('极限偏差（mm）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Theme.of(context).colorScheme.outlineVariant),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                _row(context, ['公差带', '上偏差', '下偏差'], header: true),
                _row(context, [
                  '孔 ${r.hole.zone.code}',
                  formatUmSigned(r.hole.upperUm),
                  formatUmSigned(r.hole.lowerUm),
                ]),
                if (r.shaft != null)
                  _row(context, [
                    '轴 ${r.shaft!.zone.code}',
                    formatUmSigned(r.shaft!.upperUm),
                    formatUmSigned(r.shaft!.lowerUm),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fitCard(BuildContext context, FitQueryResult r) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('配合结果', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (r.fitType == null)
              Text('未输入轴公差带，无法计算配合。',
                  style: Theme.of(context).textTheme.bodyMedium)
            else
              for (final term in r.fitTerms)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(term.label, style: Theme.of(context).textTheme.bodyMedium),
                      Text(
                        '${term.isInterference ? formatUmMagnitude(term.um) : formatUmSigned(term.um)} mm',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  TableRow _row(BuildContext context, List<String> cells, {bool header = false}) {
    final style = header
        ? Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return TableRow(
      decoration: header
          ? BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest)
          : null,
      children: [
        for (final c in cells)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(c, style: style),
          ),
      ],
    );
  }
}