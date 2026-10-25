import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/services/quick_tools.dart';

/// 热膨胀计算器：ΔL = α × L × ΔT。
class ThermalPage extends StatefulWidget {
  const ThermalPage({super.key});

  @override
  State<ThermalPage> createState() => _ThermalPageState();
}

class _ThermalPageState extends State<ThermalPage> {
  String _material = '铝合金';
  final _alphaController = TextEditingController();
  final _lengthController = TextEditingController(text: '100');
  final _deltaTController = TextEditingController(text: '10');
  double? _customAlpha;

  @override
  void initState() {
    super.initState();
    _alphaController.text =
        QuickTools.expansionCoefficients[_material].toString();
    _alphaController.addListener(() {
      final v = double.tryParse(_alphaController.text);
      setState(() => _customAlpha = v);
    });
  }

  @override
  void dispose() {
    _alphaController.dispose();
    _lengthController.dispose();
    _deltaTController.dispose();
    super.dispose();
  }

  double get _alpha {
    if (_customAlpha != null && _customAlpha! > 0) return _customAlpha!;
    final preset = QuickTools.expansionCoefficients[_material]!;
    // 系数被手动改动时以手动值为准
    return double.tryParse(_alphaController.text) ?? preset;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = double.tryParse(_lengthController.text);
    final dt = double.tryParse(_deltaTController.text);
    final valid = l != null && l > 0 && dt != null;
    final dl = valid
        ? QuickTools.thermalExpansionUm(
            alphaUmPerMC: _alpha, lengthMm: l, deltaT: dt)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('热膨胀计算器')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _material,
            decoration: const InputDecoration(
                labelText: '材料（自动带出线膨胀系数）',
                border: OutlineInputBorder()),
            items: [
              for (final e in QuickTools.expansionCoefficients.entries)
                DropdownMenuItem(
                    value: e.key, child: Text('${e.key}（${e.value} μm/m·°C）')),
              const DropdownMenuItem(
                  value: '自定义', child: Text('自定义系数…')),
            ],
            onChanged: (v) {
              setState(() {
                _material = v!;
                if (v != '自定义') {
                  _customAlpha = null;
                  _alphaController.text =
                      QuickTools.expansionCoefficients[v].toString();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _alphaController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: const InputDecoration(
              labelText: '线膨胀系数 α (μm/m·°C)',
              helperText: '选材料自动填充，也可手动修改',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lengthController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: '尺寸 L (mm)',
                      border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _deltaTController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))
                  ],
                  decoration: const InputDecoration(
                      labelText: '温差 ΔT (°C，可负)',
                      border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
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
                  Text('热变形量 ΔL',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Text(
                    dl == null
                        ? '请输入有效数值'
                        : '${dl.abs().toStringAsFixed(1)} μm（${dl >= 0 ? "伸长" : "缩短"} ${(dl.abs() / 1000).toStringAsFixed(4)} mm）',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 4),
                  Text('公式：ΔL = α × L × ΔT',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onPrimaryContainer)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '工程提示：精密测量在 20℃ 标准温度（ISO 1）下进行；铝件对温度最敏感——'
            '100 mm 铝件温升 10℃ 变形约 23 μm，对 ±0.02 级公差是致命的。【系数为典型值待核对】',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
