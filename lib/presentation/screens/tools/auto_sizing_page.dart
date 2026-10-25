import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 非标自动化选型助手：滚珠丝杠 / 直线导轨 / 气缸。
class AutoSizingPage extends StatelessWidget {
  const AutoSizingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('非标选型助手'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: '丝杠选型'),
            Tab(text: '导轨选型'),
            Tab(text: '气缸选型'),
            Tab(text: '气缸出力'),
          ]),
        ),
        body: TabBarView(
            children: [_ScrewTab(), _RailTab(), _CylSizeTab(), _CylForceTab()]),
      ),
    );
  }
}

// ==================== 丝杠选型 ====================
class _ScrewTab extends StatefulWidget {
  @override
  State<_ScrewTab> createState() => _ScrewTabState();
}

class _ScrewTabState extends State<_ScrewTab> {
  final _mass = TextEditingController(text: '20');
  final _stroke = TextEditingController(text: '600');
  final _speed = TextEditingController(text: '300');
  final _acc = TextEditingController(text: '0.1');
  final _prec = TextEditingController(text: '0.02');
  final _mu = TextEditingController(text: '0.1');
  final _nmax = TextEditingController(text: '3000');

  Map<String, String>? _rows;
  String? _note;

  void _calc() {
    final m = double.tryParse(_mass.text);
    final s = double.tryParse(_stroke.text);
    final v = double.tryParse(_speed.text);
    final t = double.tryParse(_acc.text);
    final prec = double.tryParse(_prec.text);
    final mu = double.tryParse(_mu.text);
    final nmax = double.tryParse(_nmax.text);
    if (m == null || v == null || t == null || t <= 0 || v <= 0 ||
        nmax == null || nmax <= 0 || s == null || s <= 0 ||
        mu == null || mu < 0) {
      setState(() => _rows = {'错误': '请完整填写正数'});
      return;
    }
    final a = v / 1000 / t; // m/s²
    final f = QuickTools.ballscrewAxialForce(
        massKg: m, accelMss: a, frictionCoef: mu);
    final leadMin = QuickTools.ballscrewMinLead(
        speedMmS: v, maxRpm: nmax);
    // 标准导程系列向上取
    final leadRec = leadMin <= 5
        ? 5.0
        : leadMin <= 10
            ? 10.0
            : leadMin <= 20
                ? 20.0
                : leadMin <= 32
                    ? 32.0
                    : 40.0;
    final j = QuickTools.ballscrewInertia(massKg: m, leadMm: leadRec);
    final rpm = v * 60 / leadRec;

    // 精度等级经验映射【待核对】
    String grade;
    if (prec == null || prec >= 0.1) {
      grade = 'C7（传输级）';
    } else if (prec >= 0.02) {
      grade = 'C5（定位级）';
    } else {
      grade = 'C3（精密级）';
    }
    // 直径经验映射【待核对】
    String dia;
    if (f <= 500 && s <= 1000) {
      dia = 'Ø16~20';
    } else if (f <= 2000 && s <= 1500) {
      dia = 'Ø25~32';
    } else if (f <= 6000) {
      dia = 'Ø40~50';
    } else {
      dia = 'Ø50+，需校核压杆稳定';
    }

    setState(() {
      _rows = {
        '轴向力 F = m·a + μmg': '${f.toStringAsFixed(0)} N',
        '最小导程 Ph_min = V·60/n_max':
            '${leadMin.toStringAsFixed(1)} mm',
        '推荐导程（标准系列）': 'Ph ${leadRec.toStringAsFixed(0)} mm',
        '工作转速': '${rpm.toStringAsFixed(0)} rpm（≤ $nmax）',
        '折算惯量 J = m·(Ph/2π)²':
            '${(j * 1e4).toStringAsFixed(1)} ×10⁻⁴ kg·m²',
        '推荐直径（经验）【待核对】': dia,
        '推荐精度等级（经验）【待核对】': grade,
      };
      _note = s > 1500
          ? '行程 ${s.toStringAsFixed(0)} mm 较长：校核临界转速与压杆稳定，'
              '建议一端固定一端支撑。'
          : '建议一端固定（DF 角接触对）+ 一端支撑；联轴器处惯量另计。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('输入工况', style: Theme.of(context).textTheme.titleSmall),
                CalcField(_mass, '负载质量（含滑台）', 'kg'),
                CalcField(_stroke, '工作行程', 'mm'),
                CalcField(_speed, '最大速度', 'mm/s'),
                CalcField(_acc, '加减速时间', 's'),
                CalcField(_prec, '定位精度要求', '±mm（如 0.02）'),
                CalcField(_mu, '导轨摩擦系数', '一般 0.05~0.15'),
                CalcField(_nmax, '电机最高转速', 'rpm'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _calc,
            icon: const Icon(Icons.bolt),
            label: const Text('开始选型')),
        const SizedBox(height: 12),
        if (_rows != null) CalcResult(rows: _rows!),
        if (_note != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_note!,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(height: 1.5)),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ==================== 导轨选型 ====================
class _RailTab extends StatefulWidget {
  @override
  State<_RailTab> createState() => _RailTabState();
}

class _RailTabState extends State<_RailTab> {
  final _mass = TextEditingController(text: '50');
  final _impact = TextEditingController(text: '1.5');
  final _target = TextEditingController(text: '20000');
  final _stroke = TextEditingController(text: '600');

  Map<String, String>? _rows;

  static const _railMap = [
    ['15 宽', 'C ≈ 6~10 kN'],
    ['20 宽', 'C ≈ 12~20 kN'],
    ['25 宽', 'C ≈ 20~35 kN'],
    ['30 宽', 'C ≈ 35~50 kN'],
    ['35 宽', 'C ≈ 50~80 kN'],
    ['45 宽', 'C ≈ 80~130 kN'],
  ];

  void _calc() {
    final m = double.tryParse(_mass.text);
    final k = double.tryParse(_impact.text);
    final target = double.tryParse(_target.text);
    if (m == null || k == null || target == null ||
        m <= 0 || k <= 0 || target <= 0) {
      setState(() => _rows = {'错误': '请完整填写正数'});
      return;
    }
    // 2 轨 4 滑块标准布置：每滑块静载 = mg/4 × 冲击系数
    final perSlider = m * 9.81 / 4 * k; // N
    final pKn = perSlider / 1000;
    final creq = QuickTools.guideRequiredLoad(
        equivalentLoadKN: pKn, targetLifeKm: target);

    String rail;
    if (creq <= 8) {
      rail = '15 宽';
    } else if (creq <= 16) {
      rail = '20 宽';
    } else if (creq <= 27) {
      rail = '25 宽';
    } else if (creq <= 42) {
      rail = '30 宽';
    } else if (creq <= 65) {
      rail = '35 宽';
    } else {
      rail = '45 宽及以上';
    }

    setState(() {
      _rows = {
        '布置方式': '2 轨 × 4 滑块（标准）',
        '每滑块等效载荷 P': '${pKn.toStringAsFixed(2)} kN'
            '（= mg/4 × 冲击系数$k）',
        '目标寿命': '${target.toStringAsFixed(0)} km',
        '所需动载荷 C_req': '${creq.toStringAsFixed(1)} kN',
        '推荐规格（经验）【待核对】': rail,
        '公式': 'P = mg/4·k；C_req = P·(L/50)^(1/3)',
      };
      if (_stroke.text.isNotEmpty) {
        final s = double.tryParse(_stroke.text);
        if (s != null && s > 0) {
          _rows!['导轨长度建议'] =
              '≥ ${s.toStringAsFixed(0)} mm（有效行程）+ 滑块间距余量，'
              '端部加限位与防尘刮屑板';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('输入工况', style: Theme.of(context).textTheme.titleSmall),
                CalcField(_mass, '负载总质量（含台面）', 'kg'),
                CalcField(_impact, '冲击/动载系数 k', '平稳 1.1~1.5，振动 2~3'),
                CalcField(_target, '目标寿命', 'km（一般 20000~50000）'),
                CalcField(_stroke, '工作行程', 'mm'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _calc,
            icon: const Icon(Icons.bolt),
            label: const Text('开始选型')),
        const SizedBox(height: 12),
        if (_rows != null) CalcResult(rows: _rows!),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('常见宽度系列动载荷范围【待核对，随品牌差异大】',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              for (final r in _railMap)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(r[0], style: const TextStyle(fontSize: 11.5)),
                      Text(r[1],
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ==================== 气缸选型 ====================
class _CylSizeTab extends StatefulWidget {
  @override
  State<_CylSizeTab> createState() => _CylSizeTabState();
}

class _CylSizeTabState extends State<_CylSizeTab> {
  final _load = TextEditingController(text: '200');
  final _p = TextEditingController(text: '0.5');
  final _eta = TextEditingController(text: '0.5');
  final _stroke = TextEditingController(text: '200');
  final _cpm = TextEditingController(text: '10');

  Map<String, String>? _rows;

  void _calc() {
    final load = double.tryParse(_load.text);
    final p = double.tryParse(_p.text);
    final eta = double.tryParse(_eta.text);
    if (load == null || p == null || eta == null ||
        load <= 0 || p <= 0 || eta <= 0 || eta > 1) {
      setState(() => _rows = {'错误': '请填写正数（负载率 ≤1）'});
      return;
    }
    final minBore = QuickTools.cylinderBore(
        loadN: load, pressureMPa: p, loadFactor: eta);
    final bore = QuickTools.standardBore(minBore);
    final map = <String, String>{
      '所需理论推力 = F/η': '${(load / eta).toStringAsFixed(0)} N',
      '计算最小缸径': '${minBore.toStringAsFixed(1)} mm',
      '推荐标准缸径': 'Ø${bore.toStringAsFixed(0)}',
      '公式': 'D = √(4F/(η·p·π))',
    };
    final st = double.tryParse(_stroke.text);
    final cpm = double.tryParse(_cpm.text);
    if (st != null && st > 0 && cpm != null && cpm > 0) {
      // 耗气量（ANR）= A×行程×(p+0.101)/0.101，往返 ×2×频次
      final areaCm2 = 0.7853981634 * bore * bore / 100;
      final perStrokeL =
          areaCm2 * st / 10 * (p + 0.1013) / 0.1013 / 1000;
      map['单行程耗气（ANR）'] = '${perStrokeL.toStringAsFixed(3)} L';
      map['每分钟耗气（往返×$cpm）'] =
          '${(perStrokeL * 2 * cpm).toStringAsFixed(1)} L/min（估算）';
    }
    setState(() => _rows = map);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('输入工况', style: Theme.of(context).textTheme.titleSmall),
                CalcField(_load, '负载力 F', 'N（1 kgf ≈ 9.8 N）'),
                CalcField(_p, '使用气压 p', 'MPa（典型 0.4~0.6）'),
                CalcField(_eta, '负载率 η', '0.5（动态）~0.7（静态）'),
                CalcField(_stroke, '行程', 'mm（用于耗气量）'),
                CalcField(_cpm, '每分钟往返次数', '次/分'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _calc,
            icon: const Icon(Icons.bolt),
            label: const Text('开始选型')),
        const SizedBox(height: 12),
        if (_rows != null) CalcResult(rows: _rows!),
        const SizedBox(height: 8),
        Text(
          '标准缸径系列：6/10/16/20/25/32/40/50/63/80/100/125/160/200。'
          '速度 >300 mm/s 建议选可调缓冲；水平推负载按 η≤0.5 保守取【经验法则】。'
          '耗气量为估算【待核对】。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ==================== 气缸出力 ====================
class _CylForceTab extends StatefulWidget {
  @override
  State<_CylForceTab> createState() => _CylForceTabState();
}

class _CylForceTabState extends State<_CylForceTab> {
  final _bore = TextEditingController(text: '40');
  final _rod = TextEditingController(text: '16');
  final _p = TextEditingController(text: '0.5');
  final _eta = TextEditingController(text: '0.5');

  Map<String, String>? _rows;

  void _calc() {
    final d = double.tryParse(_bore.text);
    final rod = double.tryParse(_rod.text) ?? d! * 0.4;
    final p = double.tryParse(_p.text);
    final eta = double.tryParse(_eta.text);
    if (d == null || p == null || eta == null ||
        d <= 0 || p <= 0 || eta <= 0 || rod >= d) {
      setState(() => _rows = {'错误': '请检查输入（杆径需小于缸径）'});
      return;
    }
    final push = QuickTools.cylinderPush(boreMm: d, pressureMPa: p);
    final pull =
        QuickTools.cylinderPull(boreMm: d, rodMm: rod, pressureMPa: p);
    setState(() {
      _rows = {
        '理论推力 = π/4·D²·p': '${push.toStringAsFixed(1)} N',
        '理论拉力 = π/4·(D²−d²)·p': '${pull.toStringAsFixed(1)} N',
        '可用推力（×0.9 效率）': '${(push * 0.9).toStringAsFixed(1)} N',
        '允许负载（可用 × η=$eta）':
            '${(push * 0.9 * eta).toStringAsFixed(1)} N',
        '公式': '1 mm²·MPa = 1 N',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('输入', style: Theme.of(context).textTheme.titleSmall),
                CalcField(_bore, '缸径 D', 'mm'),
                CalcField(_rod, '杆径 d', 'mm（标准杆径见下）'),
                CalcField(_p, '气压 p', 'MPa'),
                CalcField(_eta, '负载率 η', '0.5 动态 / 0.7 静态'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _calc,
            icon: const Icon(Icons.bolt),
            label: const Text('开始计算')),
        const SizedBox(height: 12),
        if (_rows != null) CalcResult(rows: _rows!),
        const SizedBox(height: 8),
        Text(
          '常用缸径-标准杆径（JIS【待核对】）：Ø20-8 / Ø25-10 / Ø32-12 / '
          'Ø40-16 / Ø50-20 / Ø63-20 / Ø80-25 / Ø100-32。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
