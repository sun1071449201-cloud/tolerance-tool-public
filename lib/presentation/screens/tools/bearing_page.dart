import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/services/quick_tools.dart';

/// 轴承 L10 寿命估算器：L10 = (C/P)^ε；L10h = L10×10⁶/(60n)。
class BearingPage extends StatefulWidget {
  const BearingPage({super.key});

  @override
  State<BearingPage> createState() => _BearingPageState();
}

class _BearingPageState extends State<BearingPage> {
  final _cController = TextEditingController(text: '25.0');
  final _pController = TextEditingController(text: '5.0');
  final _rpmController = TextEditingController(text: '1500');
  bool _roller = false;

  @override
  void dispose() {
    _cController.dispose();
    _pController.dispose();
    _rpmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = double.tryParse(_cController.text);
    final p = double.tryParse(_pController.text);
    final n = double.tryParse(_rpmController.text);
    final valid = c != null && c > 0 && p != null && p > 0;

    final l10 = valid
        ? QuickTools.bearingL10MillionRevs(cKn: c, pKn: p, roller: _roller)
        : null;
    final hours = (valid && n != null && n > 0)
        ? QuickTools.bearingL10Hours(l10Million: l10!, rpm: n)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('轴承 L10 寿命估算')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: '额定动载荷 C (kN)',
                      border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _pController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: '当量动载荷 P (kN)',
                      border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rpmController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                      labelText: '转速 n (rpm)',
                      border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<bool>(
                  value: _roller,
                  decoration: const InputDecoration(
                      labelText: '轴承类型',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('球轴承 (ε=3)')),
                    DropdownMenuItem(
                        value: true, child: Text('滚子轴承 (ε=10/3)')),
                  ],
                  onChanged: (v) => setState(() => _roller = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('基本额定寿命',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Text(
                    l10 == null
                        ? '请输入有效载荷'
                        : 'L10 = ${l10.toStringAsFixed(1)} 百万转',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hours == null
                        ? '（输入转速可换算小时寿命）'
                        : '≈ ${_fmtHours(hours)} 小时（${(hours / 8760).toStringAsFixed(1)} 年连续运转）',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '公式：球轴承 L10=(C/P)³；滚子轴承 L10=(C/P)^(10/3)；L10h = L10×10⁶/(60n)。\n'
            'L10 是 90% 可靠度下的寿命。C/P 比值经验：一般机械 ≥3~5，重要场合 ≥8~10。\n'
            '修正：有冲击/温度/润滑修正时用 aISO 修正额定寿命（本估算为基本额定寿命）。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  String _fmtHours(double h) {
    if (h >= 100000) return '${(h / 1000).toStringAsFixed(0)}k';
    return h.toStringAsFixed(0);
  }
}
