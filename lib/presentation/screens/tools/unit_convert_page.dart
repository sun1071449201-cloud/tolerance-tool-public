import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/services/quick_tools.dart';

/// 单位换算：MPa↔kgf/cm²、英寸↔毫米、N·m↔kgf·m。
class UnitConvertPage extends StatefulWidget {
  const UnitConvertPage({super.key});

  @override
  State<UnitConvertPage> createState() => _UnitConvertPageState();
}

class _UnitConvertPageState extends State<UnitConvertPage> {
  final _mpa = TextEditingController(text: '100');
  final _kgfcm2 = TextEditingController();
  final _inch = TextEditingController(text: '1');
  final _mm = TextEditingController();
  final _nm = TextEditingController(text: '10');
  final _kgfm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncMpa('100');
    _syncInch('1');
    _syncNm('10');
  }


  void _syncMpa(String v) {
    final d = double.tryParse(v);
    _kgfcm2.text =
        d == null ? '' : QuickTools.mpaToKgfCm2(d).toStringAsFixed(3);
  }

  void _syncKgf(String v) {
    final d = double.tryParse(v);
    _mpa.text =
        d == null ? '' : QuickTools.kgfCm2ToMpa(d).toStringAsFixed(4);
  }

  void _syncInch(String v) {
    final d = double.tryParse(v);
    _mm.text = d == null ? '' : QuickTools.inchToMm(d).toStringAsFixed(4);
  }

  void _syncMm(String v) {
    final d = double.tryParse(v);
    _inch.text = d == null ? '' : QuickTools.mmToInch(d).toStringAsFixed(5);
  }

  void _syncNm(String v) {
    final d = double.tryParse(v);
    _kgfm.text = d == null ? '' : QuickTools.nmToKgfM(d).toStringAsFixed(4);
  }

  void _syncKgfm(String v) {
    final d = double.tryParse(v);
    _nm.text = d == null ? '' : QuickTools.kgfMToNm(d).toStringAsFixed(4);
  }

  @override
  void dispose() {
    for (final c in [_mpa, _kgfcm2, _inch, _mm, _nm, _kgfm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('单位换算')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row(context, 'MPa', _mpa, _syncMpa, 'kgf/cm²', _kgfcm2, _syncKgf,
              hint: '1 MPa ≈ 10.197 kgf/cm²'),
          _row(context, '英寸 inch', _inch, _syncInch, '毫米 mm', _mm, _syncMm,
              hint: '1 in = 25.4 mm（精确）'),
          _row(context, 'N·m', _nm, _syncNm, 'kgf·m', _kgfm, _syncKgfm,
              hint: '1 kgf·m ≈ 9.807 N·m'),
          const SizedBox(height: 12),
          Text('输入任一侧数值，另一侧实时换算。',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String labelA,
    TextEditingController a,
    ValueChanged<String> onA,
    String labelB,
    TextEditingController b,
    ValueChanged<String> onB, {
    String? hint,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _field(labelA, a, onA)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.swap_horiz),
                ),
                Expanded(child: _field(labelB, b, onB)),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint, style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(
      String label, TextEditingController c, ValueChanged<String> onChanged) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
          labelText: label, isDense: true, border: const OutlineInputBorder()),
      onChanged: onChanged,
    );
  }
}
