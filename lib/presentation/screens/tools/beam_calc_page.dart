import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/services/quick_tools.dart';

/// 梁挠度 + 截面特性一体化计算器。
class BeamCalcPage extends StatefulWidget {
  const BeamCalcPage({super.key});

  @override
  State<BeamCalcPage> createState() => _BeamCalcPageState();
}

class _BeamCalcPageState extends State<BeamCalcPage> {
  // 材料
  String _material = '钢';
  // 截面
  String _sectionType = 'rect';
  final _bCtrl = TextEditingController(text: '20');
  final _hCtrl = TextEditingController(text: '40');
  final _dCtrl = TextEditingController(text: '30');
  final _innerCtrl = TextEditingController(text: '20');
  // 载荷
  String _beamType = 'cantilever';
  final _fCtrl = TextEditingController(text: '100');
  final _lCtrl = TextEditingController(text: '200');

  double get _i {
    switch (_sectionType) {
      case 'rect':
        final b = double.tryParse(_bCtrl.text) ?? 0;
        final h = double.tryParse(_hCtrl.text) ?? 0;
        return QuickTools.rectSection(b, h).$1;
      case 'circle':
        final d = double.tryParse(_dCtrl.text) ?? 0;
        return QuickTools.circleSection(d).$1;
      case 'tube':
        final outer = double.tryParse(_dCtrl.text) ?? 0;
        final inner = double.tryParse(_innerCtrl.text) ?? 0;
        return QuickTools.tubeSection(outer, inner).$1;
      default:
        return 0;
    }
  }

  double get _w {
    switch (_sectionType) {
      case 'rect':
        return QuickTools.rectSection(
            double.tryParse(_bCtrl.text) ?? 0,
            double.tryParse(_hCtrl.text) ?? 0).$2;
      case 'circle':
        return QuickTools
            .circleSection(double.tryParse(_dCtrl.text) ?? 0).$2;
      case 'tube':
        return QuickTools.tubeSection(
            double.tryParse(_dCtrl.text) ?? 0,
            double.tryParse(_innerCtrl.text) ?? 0).$2;
      default:
        return 0;
    }
  }

  double? get _deflection {
    final f = double.tryParse(_fCtrl.text);
    final l = double.tryParse(_lCtrl.text);
    final e = QuickTools.elasticModuli[_material] ?? 207;
    if (f == null || l == null || l <= 0 || _i <= 0) return null;
    if (_beamType == 'cantilever') {
      return QuickTools.cantileverTipLoad(
          forceN: f, lengthMm: l, eGPa: e, iMm4: _i);
    }
    return QuickTools.simplySupportedCenterLoad(
        forceN: f, lengthMm: l, eGPa: e, iMm4: _i);
  }

  double? get _maxStress {
    final f = double.tryParse(_fCtrl.text) ?? 0;
    final l = double.tryParse(_lCtrl.text) ?? 0;
    if (_w <= 0 || l <= 0) return null;
    // 简化：弯矩 M = F·L/4（简支中点）/ F·L（悬臂端）
    final m = _beamType == 'cantilever' ? f * l : f * l / 4;
    return m / _w; // MPa（N·mm/mm³ = MPa）
  }

  @override
  void dispose() {
    for (final c in [_bCtrl, _hCtrl, _dCtrl, _innerCtrl, _fCtrl, _lCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = _deflection;
    final sigma = _maxStress;

    return Scaffold(
      appBar: AppBar(title: const Text('梁挠度与截面特性')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 材料
          DropdownButtonFormField<String>(
            value: _material,
            decoration: const InputDecoration(
                labelText: '材料（弹性模量 E）', border: OutlineInputBorder()),
            items: [
              for (final e in QuickTools.elasticModuli.entries)
                DropdownMenuItem(
                    value: e.key, child: Text('${e.key}（E=${e.value} GPa）')),
            ],
            onChanged: (v) => setState(() => _material = v!),
          ),
          const SizedBox(height: 12),
          // 截面
          DropdownButtonFormField<String>(
            value: _sectionType,
            decoration: const InputDecoration(
                labelText: '截面形状', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'rect', child: Text('矩形 b×h')),
              DropdownMenuItem(value: 'circle', child: Text('实心圆 Ød')),
              DropdownMenuItem(value: 'tube', child: Text('圆管 D×d')),
            ],
            onChanged: (v) => setState(() => _sectionType = v!),
          ),
          const SizedBox(height: 12),
          if (_sectionType == 'rect')
            Row(children: [
              Expanded(
                  child: _num(_bCtrl, '宽 b (mm)')),
              const SizedBox(width: 8),
              Expanded(
                  child: _num(_hCtrl, '高 h (mm)')),
            ])
          else if (_sectionType == 'circle')
            _num(_dCtrl, '直径 d (mm)')
          else
            Row(children: [
              Expanded(
                  child: _num(_dCtrl, '外径 D (mm)')),
              const SizedBox(width: 8),
              Expanded(
                  child: _num(_innerCtrl, '内径 d (mm)')),
            ]),
          const SizedBox(height: 12),
          // 梁
          DropdownButtonFormField<String>(
            value: _beamType,
            decoration: const InputDecoration(
                labelText: '梁类型', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                  value: 'cantilever', child: Text('悬臂梁（端部力 F）')),
              DropdownMenuItem(
                  value: 'simply', child: Text('简支梁（中点力 F）')),
            ],
            onChanged: (v) => setState(() => _beamType = v!),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _num(_fCtrl, '载荷 F (N)')),
            const SizedBox(width: 8),
            Expanded(child: _num(_lCtrl, '长度 L (mm)')),
          ]),
          const SizedBox(height: 16),
          // 截面特性结果
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text('截面特性',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.onSecondaryContainer)),
                const SizedBox(height: 4),
                Text('I = ${_i.toStringAsFixed(0)} mm⁴   W = ${_w.toStringAsFixed(0)} mm³',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSecondaryContainer)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          // 挠度结果
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text('端部/中点挠度 δ',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.onPrimaryContainer)),
                const SizedBox(height: 6),
                Text(
                  d == null
                      ? '请输入完整参数'
                      : '${d.toStringAsFixed(3)} mm',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer),
                ),
                if (sigma != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '最大弯曲应力 σ ≈ ${sigma.toStringAsFixed(1)} MPa',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _beamType == 'cantilever'
                      ? '悬臂梁：δ = FL³ / 3EI'
                      : '简支梁：δ = FL³ / 48EI',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '截面惯性矩 I 与抗弯截面模量 W 用于梁的刚度与强度校核。'
            'E 为弹性模量（钢≈207 GPa，铝≈69 GPa）【待核对】。'
            '挠度许用值一般取 L/200~L/500（精密设备更严）。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _num(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
      ],
      decoration: InputDecoration(
          labelText: label, isDense: true, border: const OutlineInputBorder()),
      onChanged: (_) => setState(() {}),
    );
  }
}
