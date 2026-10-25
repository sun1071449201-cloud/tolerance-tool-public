import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 尺寸链（公差堆叠）计算器：输入各环公差，输出封闭环公差。
/// 支持极值法（worst-case）与方和根法（RSS）。
class ToleranceChainPage extends StatefulWidget {
  const ToleranceChainPage({super.key});

  @override
  State<ToleranceChainPage> createState() => _ToleranceChainPageState();
}

class _ToleranceChainPageState extends State<ToleranceChainPage> {
  final _controllers = <TextEditingController>[];
  final _links = <double>[0.05, 0.1, 0.08, 0.06];
  bool _useRss = false;

  @override
  void initState() {
    super.initState();
    for (final v in _links) {
      final c = TextEditingController(text: v.toString());
      c.addListener(() => setState(() {}));
      _controllers.add(c);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  double get _worstCase {
    var sum = 0.0;
    for (final c in _controllers) {
      sum += double.tryParse(c.text) ?? 0;
    }
    return sum;
  }

  double get _rss {
    var sumSq = 0.0;
    for (final c in _controllers) {
      final v = double.tryParse(c.text) ?? 0;
      sumSq += v * v;
    }
    return sumSq <= 0 ? 0 : sumSq;
  }

  void _addLink() {
    setState(() {
      final c = TextEditingController();
      c.addListener(() => setState(() {}));
      _controllers.add(c);
      _links.add(0);
    });
  }

  void _removeLink(int index) {
    if (_controllers.length <= 2) return;
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wc = _worstCase;
    final rss = _useRss ? _rss : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('尺寸链公差堆叠计算器')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('各组成环公差（mm）',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('输入各组成环的公差带宽（T 值），计算封闭环的累积公差。',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (var i = 0; i < _controllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controllers[i],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                      decoration: InputDecoration(
                        labelText: '环 ${i + 1} 公差 T${i + 1} (mm)',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    tooltip: '删除此环',
                    onPressed:
                        _controllers.length > 2 ? () => _removeLink(i) : null,
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addLink,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('增加一环'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('使用方和根法（RSS）'),
            subtitle: const Text('关闭则使用极值法（Worst-case）'),
            value: _useRss,
            onChanged: (v) => setState(() => _useRss = v),
          ),
          const SizedBox(height: 16),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('封闭环累积公差',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Text(
                    '±${(_useRss ? rss : wc).toStringAsFixed(4)} mm',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _useRss
                        ? '方和根法（RSS）：假设各环独立随机分布，结果比极值法宽松，适用于大批量'
                        : '极值法（Worst-case）：所有环同时处于极限，结果最保守，适用于小批量/关键尺寸',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '公式：极值法 T_total = ΣT_i；方和根法 T_total = √(ΣT_i²)。\n'
            '设计建议：优先 RSS（经济性好），但需确认工艺稳定且各环独立；'
            '关键/安全尺寸用极值法兜底。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
