import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/services/quick_tools.dart';

/// 机械传动计算器集合页：功率/扭矩、齿轮参数、弹簧刚度、压配合。
class MechCalcPage extends StatelessWidget {
  const MechCalcPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: prefer_const_constructors
    return DefaultTabController(
      length: 5,
      // ignore: prefer_const_constructors
      child: Scaffold(
        appBar: AppBar(
          title: const Text('机械传动计算'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '功率/扭矩'),
              Tab(text: '齿轮参数'),
              Tab(text: '弹簧刚度'),
              Tab(text: '压配合'),
              Tab(text: '同步带'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _PowerTab(),
          _GearTab(),
          _SpringTab(),
          _PressFitTab(),
          _BeltTab(),
        ]),
      ),
    );
  }
}

// ==================== 功率/扭矩 ====================
class _PowerTab extends StatefulWidget {
  @override
  State<_PowerTab> createState() => _PowerTabState();
}

class _PowerTabState extends State<_PowerTab> {
  final _tCtrl = TextEditingController(text: '24');
  final _nCtrl = TextEditingController(text: '1500');
  final _pCtrl = TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    _calcPower();
  }

  void _calcPower() {
    final t = double.tryParse(_tCtrl.text);
    final n = double.tryParse(_nCtrl.text);
    if (t != null && n != null && n > 0) {
      _pCtrl.text = QuickTools.torqueToPowerKw(t, n).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    for (final c in [_tCtrl, _nCtrl, _pCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _row(context, '扭矩 T (N·m)', _tCtrl, _calcPower),
        _row(context, '转速 n (rpm)', _nCtrl, _calcPower),
        _result(context, '功率 P', '${_pCtrl.text} kW'),
        const SizedBox(height: 12),
        Text(
          '公式：P(kW) = T × n / 9550\n'
          '反过来：T = 9550 × P / n，n = 9550 × P / T\n'
          '9550 = 60 × 1000 / (2π)，即每分钟转一圈对应的弧度换算。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 齿轮 ====================
class _GearTab extends StatefulWidget {
  @override
  State<_GearTab> createState() => _GearTabState();
}

class _GearTabState extends State<_GearTab> {
  final _mCtrl = TextEditingController(text: '2');
  final _z1Ctrl = TextEditingController(text: '20');
  final _z2Ctrl = TextEditingController(text: '40');

  @override
  void dispose() {
    for (final c in [_mCtrl, _z1Ctrl, _z2Ctrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = double.tryParse(_mCtrl.text) ?? 0;
    final z1 = double.tryParse(_z1Ctrl.text) ?? 0;
    final z2 = double.tryParse(_z2Ctrl.text) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _row(context, '模数 m (mm)', _mCtrl, () => setState(() {})),
        _row(context, '齿数 z₁（主动轮）', _z1Ctrl, () => setState(() {})),
        _row(context, '齿数 z₂（从动轮）', _z2Ctrl, () => setState(() {})),
        const SizedBox(height: 8),
        if (m > 0 && z1 > 0) ...[
          _result(context, '小轮分度圆 d₁',
              '${QuickTools.gearPitchDia(m, z1).toStringAsFixed(1)} mm'),
          _result(context, '小轮齿顶圆 da₁',
              '${QuickTools.gearAddendumDia(m, z1).toStringAsFixed(1)} mm'),
          _result(context, '小轮齿根圆 df₁',
              '${QuickTools.gearDedendumDia(m, z1).toStringAsFixed(1)} mm'),
        ],
        if (m > 0 && z2 > 0) ...[
          _result(context, '大轮分度圆 d₂',
              '${QuickTools.gearPitchDia(m, z2).toStringAsFixed(1)} mm'),
          _result(context, '大轮齿顶圆 da₂',
              '${QuickTools.gearAddendumDia(m, z2).toStringAsFixed(1)} mm'),
        ],
        if (m > 0 && z1 > 0 && z2 > 0) ...[
          _result(context, '中心距 a',
              '${QuickTools.gearCenterDistance(m, z1, z2).toStringAsFixed(1)} mm'),
          _result(context, '传动比 i',
              '${(z2 / z1).toStringAsFixed(2)} : 1'),
          _result(context, '周节 p',
              '${QuickTools.gearCircularPitch(m).toStringAsFixed(2)} mm'),
        ],
        const SizedBox(height: 12),
        Text(
          '公式（正常齿制 h*a=1, c*=0.25）：\n'
          'd = mz,  da = m(z+2),  df = m(z−2.5)\n'
          'a = m(z₁+z₂)/2,  i = z₂/z₁\n'
          '啮合条件：两轮模数和压力角必须相同。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 弹簧 ====================
class _SpringTab extends StatefulWidget {
  @override
  State<_SpringTab> createState() => _SpringTabState();
}

class _SpringTabState extends State<_SpringTab> {
  String _material = '琴钢丝/不锈钢';
  final _dCtrl = TextEditingController(text: '2');
  final _d2Ctrl = TextEditingController(text: '12');
  final _nCtrl = TextEditingController(text: '8');
  final _l0Ctrl = TextEditingController(text: '40');
  final _lminCtrl = TextEditingController(text: '30');

  @override
  void dispose() {
    for (final c in [_dCtrl, _d2Ctrl, _nCtrl, _l0Ctrl, _lminCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = QuickTools.springModuli[_material] ?? 79.3;
    final d = double.tryParse(_dCtrl.text) ?? 0;
    final d2 = double.tryParse(_d2Ctrl.text) ?? 0;
    final n = double.tryParse(_nCtrl.text) ?? 0;
    final l0 = double.tryParse(_l0Ctrl.text);
    final lmin = double.tryParse(_lminCtrl.text);
    final k = (d > 0 && d2 > 0 && n > 0)
        ? QuickTools.springRate(
            gMPa: g * 1000, wireDia: d, meanDia: d2, activeCoils: n)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _material,
          decoration: const InputDecoration(
              labelText: '弹簧材料（切变模量 G）',
              border: OutlineInputBorder()),
          items: [
            for (final e in QuickTools.springModuli.entries)
              DropdownMenuItem(
                  value: e.key,
                  child: Text('${e.key}（G=${e.value} GPa）')),
          ],
          onChanged: (v) => setState(() => _material = v!),
        ),
        const SizedBox(height: 12),
        _row(context, '线径 d (mm)', _dCtrl, () => setState(() {})),
        _row(context, '中径 D (mm)', _d2Ctrl, () => setState(() {})),
        _row(context, '有效圈数 n', _nCtrl, () => setState(() {})),
        _result(context, '弹簧刚度 k',
            k == null ? '请输入完整参数' : '${k.toStringAsFixed(2)} N/mm'),
        const SizedBox(height: 8),
        _row(context, '自由长度 L0 (mm)', _l0Ctrl, () => setState(() {})),
        _row(context, '最小工作高度 Lmin (mm)', _lminCtrl,
            () => setState(() {})),
        if (k != null && l0 != null && lmin != null && l0 > lmin) ...[
          _result(context, '最大工作变形量 λ',
              '${(l0 - lmin).toStringAsFixed(1)} mm'),
          _result(context, '对应弹簧力 F = k·λ',
              '${(k * (l0 - lmin)).toStringAsFixed(1)} N'),
          if (d > 0 && d2 > d)
            _result(context, '压并行程上限（估）n·(D−d)',
                '${(n * (d2 - d)).toStringAsFixed(1)} mm'
                '${(l0 - lmin) > n * (d2 - d) ? ' ⚠ 超限会被压死！' : ''}'),
        ],
        const SizedBox(height: 12),
        Text(
          '公式：k = G·d⁴ / (8·D³·n)  (N/mm)\n'
          '最大变形量按自由长度与最小工作高度之差；'
          '压并行程 n·(D−d) 为几何上限【近似】——'
          'λ 超过它弹簧被压死会失效应力。\n'
          '线径对刚度影响最大（四次方）；G 值【待核对】。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 压配合 ====================
class _PressFitTab extends StatefulWidget {
  @override
  State<_PressFitTab> createState() => _PressFitTabState();
}

class _PressFitTabState extends State<_PressFitTab> {
  final _deltaCtrl = TextEditingController(text: '42');
  final _diaCtrl = TextEditingController(text: '50');
  String _mat1 = '钢';
  String _mat2 = '钢';

  @override
  void dispose() {
    for (final c in [_deltaCtrl, _diaCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e1 = QuickTools.elasticModuli[_mat1] ?? 207;
    final e2 = QuickTools.elasticModuli[_mat2] ?? 207;
    final delta = double.tryParse(_deltaCtrl.text) ?? 0;
    final dia = double.tryParse(_diaCtrl.text) ?? 0;
    final p = (delta > 0 && dia > 0)
        ? QuickTools.pressFitPressure(
            interferenceUm: delta,
            diaMm: dia,
            e1GPa: e1,
            e2GPa: e2,
          )
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _row(context, '过盈量 δ (μm)', _deltaCtrl, () => setState(() {})),
        _row(context, '配合直径 d (mm)', _diaCtrl, () => setState(() {})),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _mat1,
          decoration: const InputDecoration(
              labelText: '被包容件（轴）材料',
              border: OutlineInputBorder()),
          items: [
            for (final e in QuickTools.elasticModuli.entries)
              DropdownMenuItem(value: e.key, child: Text(e.key)),
          ],
          onChanged: (v) => setState(() => _mat1 = v!),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _mat2,
          decoration: const InputDecoration(
              labelText: '包容件（孔）材料',
              border: OutlineInputBorder()),
          items: [
            for (final e in QuickTools.elasticModuli.entries)
              DropdownMenuItem(value: e.key, child: Text(e.key)),
          ],
          onChanged: (v) => setState(() => _mat2 = v!),
        ),
        _result(context, '结合面压力 p',
            p == null ? '请输入完整参数' : '${p.toStringAsFixed(1)} MPa'),
        if (p != null && dia > 0) ...[
          _result(context, '轴向传扭能力 T（估）',
              '${(p * 3.14159 * dia * dia * 0.15 / 1000).toStringAsFixed(1)} N·m'),
        ],
        const SizedBox(height: 12),
        Text(
          '简化 Lame 公式：p = δ / (d × (1/E₁ + 1/E₂))\n'
          '轴向传扭估算：T ≈ p × π × d × L × f / 2（取 L=d, f=0.15）\n'
          '铝孔配钢轴时 E 差异大，压力显著低于全钢。【E 值待核对】',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 同步带 ====================
class _BeltTab extends StatefulWidget {
  @override
  State<_BeltTab> createState() => _BeltTabState();
}

class _BeltTabState extends State<_BeltTab> {
  String _pitch = 'HTD 8M（节距 8）';
  final _z1Ctrl = TextEditingController(text: '20');
  final _z2Ctrl = TextEditingController(text: '40');
  final _aCtrl = TextEditingController(text: '300');

  static const _pitches = <String, double>{
    'HTD 2M（节距 2）': 2,
    'HTD 3M（节距 3）': 3,
    'HTD 5M（节距 5）': 5,
    'HTD 8M（节距 8）': 8,
    'HTD 14M（节距 14）': 14,
    'GT 2（节距 2.032）': 2.032,
    'GT 3（节距 3.032）': 3.032,
    'GT 5（节距 5.080）': 5.080,
  };

  @override
  void dispose() {
    for (final c in [_z1Ctrl, _z2Ctrl, _aCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pb = _pitches[_pitch] ?? 8;
    final z1 = double.tryParse(_z1Ctrl.text) ?? 0;
    final z2 = double.tryParse(_z2Ctrl.text) ?? 0;
    final a = double.tryParse(_aCtrl.text) ?? 0;
    final d1 = (z1 > 0) ? QuickTools.beltPitchDia(teeth: z1, pitchMm: pb) : null;
    final d2 = (z2 > 0) ? QuickTools.beltPitchDia(teeth: z2, pitchMm: pb) : null;
    final len = (d1 != null && d2 != null && a > 0)
        ? QuickTools.beltLength(dia1: d1, dia2: d2, centerMm: a)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: _pitch,
          decoration: const InputDecoration(
              labelText: '带型（节距 Pb）', border: OutlineInputBorder()),
          items: [
            for (final e in _pitches.entries)
              DropdownMenuItem(value: e.key, child: Text(e.key)),
          ],
          onChanged: (v) => setState(() => _pitch = v!),
        ),
        const SizedBox(height: 12),
        _row(context, '主动轮齿数 z₁', _z1Ctrl, () => setState(() {})),
        _row(context, '从动轮齿数 z₂', _z2Ctrl, () => setState(() {})),
        _row(context, '中心距 a (mm)', _aCtrl, () => setState(() {})),
        if (d1 != null) _result(context, '主动轮节圆 d₁ = z₁·Pb/π',
            '${d1.toStringAsFixed(2)} mm'),
        if (d2 != null) _result(context, '从动轮节圆 d₂',
            '${d2.toStringAsFixed(2)} mm'),
        if (z1 > 0 && z2 > 0)
          _result(context, '传动比 i', '${(z2 / z1).toStringAsFixed(2)} : 1'),
        if (len != null) _result(context, '带长（近似）L',
            '${len.toStringAsFixed(1)} mm → 选标称 ${_nearestBelt(len)}'),
        const SizedBox(height: 12),
        Text(
          '公式：d = z·Pb/π；'
          'L ≈ 2a + π(d₁+d₂)/2 + (d₂−d₁)²/(4a)【标准近似】\n'
          '轮外径 = 节径 − 2×挡边顶高（随带型不同，查带轮样本【待核对】）。\n'
          '同步带无滑差、定位准；张紧靠偏心或张紧轮，勿过紧伤带。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  String _nearestBelt(double l) {
    const nominal = [
      240, 250, 260, 280, 300, 320, 340, 360, 380, 400, 420, 440, 460, 480,
      500, 560, 600, 640, 680, 720, 800, 880, 960, 1040, 1120, 1200, 1280,
      1440, 1600, 1760, 1920, 2080, 2240, 2400
    ];
    var best = nominal.first;
    for (final n in nominal) {
      if ((n - l).abs() < (best - l).abs()) best = n;
    }
    return '$best';
  }
}

// ==================== 公共 Widget ====================
Widget _row(BuildContext context, String label,
    TextEditingController ctrl, VoidCallback onChanged) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
      ],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    ),
  );
}

Widget _result(BuildContext context, String label, String value) {
  final scheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary),
        ),
      ],
    ),
  );
}
