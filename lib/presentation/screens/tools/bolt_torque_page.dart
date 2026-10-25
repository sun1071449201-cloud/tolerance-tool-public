import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';

/// 螺栓拧紧扭矩计算器：规格 × 性能等级 × 摩擦档位 → 扭矩与预紧力。
class BoltTorquePage extends StatefulWidget {
  const BoltTorquePage({super.key});

  @override
  State<BoltTorquePage> createState() => _BoltTorquePageState();
}

class _BoltTorquePageState extends State<BoltTorquePage> {
  String _spec = 'M8';
  String _grade = '8.8';
  double _k = 0.18;

  static const _kNames = {'0.15': '润滑（K≈0.15）', '0.18': '一般（K≈0.18）', '0.2': '干燥/镀锌（K≈0.2）'};

  @override
  Widget build(BuildContext context) {
    final torque = QuickTools.boltTorqueNm(spec: _spec, grade: _grade, k: _k);
    final preload =
        QuickTools.boltPreloadKn(spec: _spec, grade: _grade);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('螺栓拧紧扭矩计算器')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _spec,
            decoration: const InputDecoration(
                labelText: '螺纹规格', border: OutlineInputBorder()),
            items: [
              for (final s in QuickTools.boltSpecs.keys)
                DropdownMenuItem(
                    value: s,
                    child: Text('$s（应力截面积 ${QuickTools.boltSpecs[s]} mm²）')),
            ],
            onChanged: (v) => setState(() => _spec = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _grade,
            decoration: const InputDecoration(
                labelText: '性能等级',
                border: OutlineInputBorder(),
                helperText:
                    '屈服强度：8.8→640 MPa，10.9→940 MPa，12.9→1100 MPa【待核对】'),
            items: [
              for (final g in QuickTools.boltGrades.keys)
                DropdownMenuItem(
                    value: g,
                    child: Text(
                        '$g 级（屈服 ${QuickTools.boltGrades[g]} MPa）')),
            ],
            onChanged: (v) => setState(() => _grade = v!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _k.toString(),
            decoration: const InputDecoration(
                labelText: '摩擦状态（扭矩系数 K）', border: OutlineInputBorder()),
            items: [
              for (final e in _kNames.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _k = double.parse(v!)),
          ),
          const SizedBox(height: 20),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('推荐拧紧扭矩（按预紧比 0.7×σy）',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer)),
                  const SizedBox(height: 6),
                  Text(
                    '${torque.toStringAsFixed(1)} N·m',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '对应预紧力 ≈ ${preload.toStringAsFixed(1)} kN ｜ 公式 T = K × F × d',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '扭矩与实际摩擦系数强相关：润滑件、镀锌件、反复装拆件的差异可达 ±30%。'
            '重要连接以工艺文件/扭矩表为准并做标记，本计算器用于快速估算。【数值待核对】',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
