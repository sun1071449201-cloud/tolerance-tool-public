import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/tolerance_models.dart';
import '../../domain/services/fit_solver_service.dart';
import '../state/book_providers.dart';
import '../state/solver_providers.dart';
import 'dimension_fit_query_page.dart';

/// 反选求解页：输入尺寸 + 配合类型 + 期望范围 → 按匹配度推荐配合组合。
class FitSolverPage extends ConsumerStatefulWidget {
  const FitSolverPage({super.key});

  @override
  ConsumerState<FitSolverPage> createState() => _FitSolverPageState();
}

class _FitSolverPageState extends ConsumerState<FitSolverPage> {
  final _sizeController = TextEditingController(text: '50');
  final _minController = TextEditingController(text: '9');
  final _maxController = TextEditingController(text: '50');
  String _fitType = 'clearance';

  static const _fitTypes = {
    'clearance': '间隙配合',
    'transition': '过渡配合',
    'interference': '过盈配合',
  };

  void _solve() {
    final size = double.tryParse(_sizeController.text);
    final min = int.tryParse(_minController.text);
    final max = int.tryParse(_maxController.text);
    if (size == null || min == null || max == null || min >= max) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请检查输入：尺寸与范围需为数字，且最小值 < 最大值')));
      return;
    }
    ref.read(solverInputProvider.notifier).state = SolverInput(
      nominalSize: size,
      fitType: _fitType,
      targetMinUm: min,
      targetMaxUm: max,
    );
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(solverResultsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('反选求解 · 配合推荐')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sizeController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                          ],
                          decoration: const InputDecoration(
                            labelText: '基本尺寸 (mm)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _fitType,
                          decoration: const InputDecoration(
                            labelText: '配合类型',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final e in _fitTypes.entries)
                              DropdownMenuItem(value: e.key, child: Text(e.value)),
                          ],
                          onChanged: (v) => setState(() => _fitType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            labelText: '期望最小 (μm)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('~'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _maxController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            labelText: '期望最大 (μm)',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '间隙/过盈量取绝对值（μm）。间隙示例：9~50；过盈示例：1~42。',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _solve,
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: const Text('开始推荐'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text('求解失败：$e',
                    style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ),
            data: (results) {
              if (results.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 32, color: scheme.outline),
                        const SizedBox(height: 8),
                        const Text('当前数据集内没有符合该范围与类型的配合'),
                        Text('可尝试放宽范围，或切换配合类型',
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final c in results) _CandidateCard(candidate: c),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({required this.candidate});

  final FitCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = candidate;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('⌀${ref.read(solverInputProvider)?.nominalSize.toStringAsFixed(0)} ${c.code}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(c.fitType.label,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.onSecondaryContainer)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('匹配度 ${(c.score * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _limit(context, c.xMinUm),
                _limit(context, c.xMaxUm),
              ],
            ),
            const Divider(height: 16),
            for (final r in c.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.kind == 'default_principle'
                          ? Icons.gavel
                          : r.kind == 'engineering_tip'
                              ? Icons.paid
                              : r.kind == 'deviation_note'
                                  ? Icons.straighten
                                  : Icons.category,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.text,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.4)),
                          Text('依据：${r.trace}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      fontSize: 9,
                                      color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  ref.read(pendingQueryProvider.notifier).state =
                      '⌀${ref.read(solverInputProvider)!.nominalSize.toStringAsFixed(0)} ${c.code}';
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const DimensionFitQueryPage()),
                    (route) => route.isFirst,
                  );
                },
                icon: const Icon(Icons.open_in_full, size: 14),
                label: const Text('到查询页看公差带图'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _limit(BuildContext context, int um) {
    final isNeg = um < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isNeg
              ? '过盈 ${(um.abs() / 1000).toStringAsFixed(3)} mm'
              : '间隙 +${(um / 1000).toStringAsFixed(3)} mm',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
