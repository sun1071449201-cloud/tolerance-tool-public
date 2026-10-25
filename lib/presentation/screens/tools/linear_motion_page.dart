import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 直线传动选型：滚珠丝杠（扭矩/转速/寿命）与直线导轨（寿命/所需动载荷）。
class LinearMotionPage extends StatelessWidget {
  const LinearMotionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('直线传动选型'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: '滚珠丝杠'),
            Tab(text: '直线导轨'),
          ]),
        ),
        body: TabBarView(children: [_BallscrewTab(), _GuideTab()]),
      ),
    );
  }
}

// ==================== 滚珠丝杠 ====================
class _BallscrewTab extends StatefulWidget {
  @override
  State<_BallscrewTab> createState() => _BallscrewTabState();
}

class _BallscrewTabState extends State<_BallscrewTab> {
  final _force = TextEditingController(text: '2000');
  final _lead = TextEditingController(text: '10');
  final _speed = TextEditingController(text: '15'); // m/min
  final _eta = TextEditingController(text: '0.9');
  final _ca = TextEditingController(text: '20');
  final _load = TextEditingController(text: '5');

  Map<String, String>? _rows;

  void _calc() {
    final f = double.tryParse(_force.text);
    final lead = double.tryParse(_lead.text);
    final v = double.tryParse(_speed.text);
    final eta = double.tryParse(_eta.text);
    if (f == null || lead == null || v == null || eta == null ||
        lead <= 0 || eta <= 0) {
      setState(() => _rows = {'错误': '请填写完整正数'});
      return;
    }
    // 转速 = 进给速度 / 导程：V(mm/min)=v×1000 → rpm = V/Ph
    final rpm = v * 1000 / lead;
    final torque = QuickTools.ballscrewTorque(
        axialForceN: f, leadMm: lead, efficiency: eta);
    final power = QuickTools.powerKw(torqueNm: torque, rpm: rpm);

    final map = <String, String>{
      '所需转速 n': '${rpm.toStringAsFixed(0)} rpm',
      '驱动扭矩 T': '${torque.toStringAsFixed(2)} N·m',
      '驱动功率 P': '${power.toStringAsFixed(2)} kW',
      '公式': 'n = V/Ph；T = F·Ph/(2πη)；P = T·n/9550',
    };

    final ca = double.tryParse(_ca.text);
    final p = double.tryParse(_load.text);
    if (ca != null && p != null && p > 0) {
      final hours = QuickTools.ballscrewL10Hours(
          dynamicLoadKN: ca, axialLoadKN: p, rpm: rpm);
      map['寿命 L10h（Ca=$ca kN, P=$p kN）'] =
          '${hours.toStringAsFixed(0)} h';
      map['寿命说明'] = 'L10=(Ca/P)³ 百万转 → 小时';
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
                CalcField(_force, '轴向负载 F', 'N'),
                CalcField(_lead, '导程 Ph', 'mm'),
                CalcField(_speed, '进给速度 V', 'm/min'),
                CalcField(_eta, '传动效率 η', '滚珠丝杠常取 0.9'),
                const SizedBox(height: 8),
                Text('寿命校核（可选）',
                    style: Theme.of(context).textTheme.titleSmall),
                CalcField(_ca, '额定动载荷 Ca', 'kN（查厂家样本）'),
                CalcField(_load, '等效轴向载荷 P', 'kN'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _calc,
          icon: const Icon(Icons.bolt),
          label: const Text('开始计算'),
        ),
        const SizedBox(height: 12),
        if (_rows != null) CalcResult(rows: _rows!),
        const SizedBox(height: 8),
        Text(
          '常用公称直径系列：16/20/25/32/40/50 mm；'
          'Ca 逐家不同【务必查样本】。支撑侧用固定单元（DF+角接触），'
          '自由侧用支撑单元。长径比大时校核临界转速与压杆稳定。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ==================== 直线导轨 ====================
class _GuideTab extends StatefulWidget {
  @override
  State<_GuideTab> createState() => _GuideTabState();
}

class _GuideTabState extends State<_GuideTab> {
  final _load = TextEditingController(text: '5');
  final _ca = TextEditingController(text: '20');
  final _stroke = TextEditingController(text: '600');
  final _cycles = TextEditingController(text: '10');
  final _target = TextEditingController(text: '20000');

  Map<String, String>? _rows;

  void _calc() {
    final p = double.tryParse(_load.text);
    final ca = double.tryParse(_ca.text);
    final stroke = double.tryParse(_stroke.text);
    final cycles = double.tryParse(_cycles.text);
    if (p == null || ca == null || p <= 0 || ca <= 0) {
      setState(() => _rows = {'错误': '请填写载荷数据（>0）'});
      return;
    }
    final map = <String, String>{};
    final lifeKm = QuickTools.guideLifeKm(
        dynamicLoadKN: ca, equivalentLoadKN: p);
    map['额定寿命 L（C=$ca kN, P=$p kN）'] =
        '${lifeKm.toStringAsFixed(0)} km';

    if (stroke != null && cycles != null && stroke > 0 && cycles > 0) {
      final hours = QuickTools.guideLifeHours(
          lifeKm: lifeKm, strokeMm: stroke, cyclesPerMin: cycles);
      map['按行程换算寿命'] = '${hours.toStringAsFixed(0)} h';
      map['行程条件'] = '行程 $stroke mm × $cycles 次/分（往返）';
    }

    final target = double.tryParse(_target.text);
    if (target != null && target > 0) {
      final creq = QuickTools.guideRequiredLoad(
          equivalentLoadKN: p, targetLifeKm: target);
      map['目标 ${target.toStringAsFixed(0)} km 所需 C_req'] =
          '${creq.toStringAsFixed(1)} kN';
      map['选型判定'] =
          creq <= ca ? '满足：C ≥ C_req ✓' : '不满足：请加大规格或加滑块数 ✗';
    }
    map['公式'] = 'L = (C/P)³ × 50 km（ISO 14728-1）';
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
                Text('输入', style: Theme.of(context).textTheme.titleSmall),
                CalcField(_load, '单滑块等效载荷 P', 'kN（含动载系数后）'),
                CalcField(_ca, '滑块额定动载荷 C', 'kN（查样本）'),
                CalcField(_stroke, '工作行程', 'mm（用于换算小时）'),
                CalcField(_cycles, '每分钟往返次数', '次/分'),
                CalcField(_target, '目标寿命', 'km（一般 20000~50000）'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _calc,
          icon: const Icon(Icons.bolt),
          label: const Text('开始计算'),
        ),
        const SizedBox(height: 12),
        if (_rows != null) CalcResult(rows: _rows!),
        const SizedBox(height: 8),
        Text(
          '等效载荷需先计入：冲击系数（平稳 1.1~1.5，振动 2~3）、'
          '力矩载荷折算、滑块数分担。两导轨四滑块布置时每滑块载荷 '
          '= W/4 ± 力矩分量【保守取最大滑块】。'
          '静载荷校核 C0 另算【ISO 14728-1 待核对】。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
