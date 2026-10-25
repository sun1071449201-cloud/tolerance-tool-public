import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/services/quick_tools.dart';

/// 表面粗糙度 Ra/Rz 对照转换器。
class RoughnessPage extends StatefulWidget {
  const RoughnessPage({super.key});

  @override
  State<RoughnessPage> createState() => _RoughnessPageState();
}

class _RoughnessPageState extends State<RoughnessPage> {
  final _raController = TextEditingController(text: '1.6');
  final _rzController = TextEditingController();
  bool _syncing = false;

  void _onRaChanged(String v) {
    if (_syncing) return;
    final ra = double.tryParse(v);
    setState(() {
      _syncing = true;
      _rzController.text = ra == null ? '' : QuickTools.raToRz(ra).toString();
      _syncing = false;
    });
  }

  void _onRzChanged(String v) {
    if (_syncing) return;
    final rz = double.tryParse(v);
    setState(() {
      _syncing = true;
      _raController.text = rz == null ? '' : QuickTools.rzToRa(rz).toString();
      _syncing = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _onRaChanged('1.6');
  }

  @override
  void dispose() {
    _raController.dispose();
    _rzController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ra / Rz 对照转换')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _raController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Ra (μm)',
                      border: OutlineInputBorder()),
                  onChanged: _onRaChanged,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.swap_horiz),
              ),
              Expanded(
                child: TextField(
                  controller: _rzController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Rz (μm)',
                      border: OutlineInputBorder()),
                  onChanged: _onRzChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _table(context),
          const SizedBox(height: 12),
          Text(
            '对照关系为经验值 Rz ≈ (4~7)×Ra 的常用标准系列档位【待核对，以 GB/T 1031 / ISO 4287 为准】。\n'
            '注意：Ra 是算术平均偏差（默认参数），Rz 是最大轮廓高度（对个别深划痕敏感）——'
            '两者没有严格换算公式，本表仅供选型参考。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const entries = QuickTools.raRzPairs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Table(
          border: TableBorder.all(color: scheme.outlineVariant),
          children: [
            TableRow(
              decoration:
                  BoxDecoration(color: scheme.surfaceContainerHighest),
              children: const [
                Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Ra (μm)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Rz (μm)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            for (final e in entries)
              TableRow(children: [
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(e.$1.toString())),
                Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(e.$2.toString())),
              ]),
          ],
        ),
      ),
    );
  }
}
