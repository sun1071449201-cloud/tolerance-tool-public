import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/services/quick_tools.dart';

/// 重量计算器：选材料（带出密度）+ 形状尺寸，实时计算质量。
class WeightCalcPage extends StatefulWidget {
  const WeightCalcPage({super.key});

  @override
  State<WeightCalcPage> createState() => _WeightCalcPageState();
}

class _WeightCalcPageState extends State<WeightCalcPage> {
  String _material = '钢 / 铁';
  String _shape = 'block';
  final _d1 = TextEditingController(text: '100');
  final _d2 = TextEditingController(text: '50');
  final _d3 = TextEditingController(text: '20');

  static const _shapeNames = {
    'block': '长方体（长×宽×高）',
    'cylinder': '圆柱（直径×长）',
    'tube': '圆管（外径×内径×长）',
  };

  double? get _grams {
    final dims = [
      double.tryParse(_d1.text) ?? 0,
      double.tryParse(_d2.text) ?? 0,
      double.tryParse(_d3.text) ?? 0,
    ];
    if (dims.any((v) => v <= 0)) return null;
    if (_shape == 'tube' && dims[1] >= dims[0]) return null;
    return QuickTools.weightGrams(
      densityGcm3: QuickTools.materials[_material]!,
      shape: _shape,
      dims: _shape == 'block' ? dims : dims,
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _grams;
    return Scaffold(
      appBar: AppBar(title: const Text('重量计算器')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _material,
            decoration: const InputDecoration(
                labelText: '材料（自动带出密度）', border: OutlineInputBorder()),
            items: [
              for (final e in QuickTools.materials.entries)
                DropdownMenuItem(
                    value: e.key, child: Text('${e.key}（${e.value} g/cm³）')),
            ],
            onChanged: (v) => setState(() => _material = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _shape,
            decoration:
                const InputDecoration(labelText: '形状', border: OutlineInputBorder()),
            items: [
              for (final e in _shapeNames.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _shape = v!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _dimField(_d1, _shape == 'block' ? '长 mm' : (_shape == 'cylinder' ? '直径 mm' : '外径 mm')),
              const SizedBox(width: 8),
              if (_shape != 'cylinder')
                _dimField(_d2, _shape == 'block' ? '宽 mm' : '内径 mm'),
              if (_shape != 'cylinder') const SizedBox(width: 8),
              _dimField(_d3, _shape == 'block' ? '高 mm' : '长 mm'),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('计算结果',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Text(
                    g == null
                        ? '请输入有效尺寸'
                        : '${(g / 1000).toStringAsFixed(3)} kg（${g.toStringAsFixed(1)} g）',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('按典型密度估算，实际以材料证书为准。尺寸单位 mm。',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _dimField(TextEditingController c, String label) {
    return Expanded(
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
            labelText: label, isDense: true, border: const OutlineInputBorder()),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
