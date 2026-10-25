import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../state/book_providers.dart';
import '../widgets/states.dart';
import 'global_search_page.dart';
import 'quick_ref_detail_page.dart';
import 'tools/tolerance_chain_page.dart';
import 'tools/weight_calc_page.dart';
import 'tools/unit_convert_page.dart';
import 'tools/bolt_torque_page.dart';

/// Tab：工程速查与选型。4 大分类 + 离线 FTS 检索 + 小工具入口。
class QuickRefPage extends ConsumerStatefulWidget {
  const QuickRefPage({super.key});

  @override
  ConsumerState<QuickRefPage> createState() => _QuickRefPageState();
}

class _QuickRefPageState extends ConsumerState<QuickRefPage> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = '全部';
  String _mastery = 'all';

  static const _categories = ['全部', '材料与热处理', '表面处理', '标准件速查', '制造工艺速查'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(quickRefQueryProvider(_query));
    final progress =
        ref.watch(quickRefProgressProvider).valueOrNull ?? const <String, int>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('工程速查与选型'),
        actions: [
          IconButton(
            tooltip: '全局搜索',
            icon: const Icon(Icons.travel_explore),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GlobalSearchPage())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜索：如 M6 底孔 / 阳极氧化 / 7075',
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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final c in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final entry in const [
                  ('all', '全部状态'),
                  ('new', '未看'),
                  ('seen', '看过'),
                  ('master', '掌握'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(entry.$2,
                          style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      selected: _mastery == entry.$1,
                      onSelected: (_) =>
                          setState(() => _mastery = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 3, 6),
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const WeightCalcPage())),
                    icon: const Icon(Icons.scale, size: 16),
                    label: const Text('重量', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const UnitConvertPage())),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('单位', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BoltTorquePage())),
                    icon: const Icon(Icons.build, size: 16),
                    label: const Text('扭矩', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(3, 6, 12, 6),
                  child: FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ToleranceChainPage())),
                    icon: const Icon(Icons.account_tree, size: 16),
                    label: const Text('尺寸链', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const LoadingState(hint: '正在检索速查库…'),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: '检索失败：$e',
              ),
              data: (items) {
                var filtered = _category == '全部'
                    ? items
                    : items.where((w) => w.category == _category).toList();
                if (_mastery == 'new') {
                  filtered = filtered
                      .where((w) => (progress[w.refId] ?? 0) == 0)
                      .toList();
                } else if (_mastery == 'seen') {
                  filtered = filtered
                      .where((w) => progress[w.refId] == 1)
                      .toList();
                } else if (_mastery == 'master') {
                  filtered = filtered
                      .where((w) => progress[w.refId] == 2)
                      .toList();
                }
                if (_query.isNotEmpty && filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: '没有匹配“$_query”的速查条目',
                    subtitle: '换个关键词，或到全局搜索试试',
                    action: TextButton.icon(
                      icon: const Icon(Icons.travel_explore, size: 16),
                      label: const Text('全局搜索'),
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => GlobalSearchPage(
                                  initialQuery: _query))),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => FadeIn(
                    delay: (i % 8) * 20,
                    child: _RefCard(
                      item: filtered[i],
                      status: progress[filtered[i].refId] ?? 0,
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

class _RefCard extends StatelessWidget {
  const _RefCard({required this.item, required this.status});

  final QuickRefItem item;
  final int status;

  static IconData _categoryIcon(String category) {
    switch (category) {
      case '材料与热处理':
        return Icons.science;
      case '表面处理':
        return Icons.layers;
      case '标准件速查':
        return Icons.hardware;
      case '制造工艺速查':
        return Icons.precision_manufacturing;
      default:
        return Icons.grid_view;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => QuickRefDetailPage(refId: item.refId),
        )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_categoryIcon(item.category),
                      size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  if (status != 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        status == 2
                            ? Icons.verified
                            : Icons.visibility_outlined,
                        size: 15,
                        color: status == 2
                            ? Colors.green.shade700
                            : scheme.outline,
                      ),
                    ),
                  Expanded(
                    child: Text(item.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(item.category,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.onSecondaryContainer)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.contentMd.replaceAll(RegExp(r'[#*|`\n]'), ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.lightbulb, size: 13, color: scheme.tertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('经验：${item.tip}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.tertiary)),
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