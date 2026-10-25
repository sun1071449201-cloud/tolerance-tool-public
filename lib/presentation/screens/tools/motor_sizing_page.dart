import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/states.dart';

/// 伺服电机选型：负载扭矩 + 折算惯量 + 加速时间 → 峰值扭矩 / 功率 / 惯量比。
class MotorSizingPage extends StatefulWidget {
  const MotorSizingPage({super.key});

  @override
  State<MotorSizingPage> createState() => _MotorSizingPageState();
}

class _MotorSizingPageState extends State<MotorSizingPage> {
  final _load = TextEditingController(text: '1.0');
  final _inertia = TextEditingController(text: '10');
  final _accel = TextEditingController(text: '0.1');
  final _speed = TextEditingController(text: '3000');
  final _rotor = TextEditingController(text: '1.0');
  // RMS 三段工况：加速/匀速/减速（扭矩 N·m + 时间 s）
  final _taT = TextEditingController(text: '4.0');
  final _taS = TextEditingController(text: '0.1');
  final _tcT = TextEditingController(text: '1.0');
  final _tcS = TextEditingController(text: '1.0');
  final _tdT = TextEditingController(text: '3.0');
  final _tdS = TextEditingController(text: '0.1');

  Map<String, String>? _result;
  Map<String, String>? _rms;
  String? _warning;

  void _calc() {
    final load = double.tryParse(_load.text);
    final inertiaUm = double.tryParse(_inertia.text); // ×10⁻⁴ kg·m²
    final accel = double.tryParse(_accel.text);
    final speed = double.tryParse(_speed.text);
    final rotorUm = double.tryParse(_rotor.text);

    if (load == null || inertiaUm == null || accel == null || speed == null ||
        accel <= 0 || speed <= 0) {
      setState(() {
        _result = null;
        _warning = '请填写完整正数（加减速时间和转速必须大于 0）';
      });
      return;
    }
    final inertia = inertiaUm * 1e-4;
    final tAccel = QuickTools.accelTorque(
        inertiaKgM2: inertia, maxSpeedRpm: speed, accelTimeS: accel);
    final tPeak = QuickTools.peakTorque(
        loadTorqueNm: load,
        inertiaKgM2: inertia,
        maxSpeedRpm: speed,
        accelTimeS: accel);
    final power = QuickTools.powerKw(torqueNm: tPeak, rpm: speed);
    final alpha = speed * 2 * 3.1415926535897932 / 60 / accel;

    String? warn;
    if (rotorUm != null && rotorUm > 0) {
      final ratio = QuickTools.inertiaRatio(
          loadInertiaKgM2: inertia, rotorInertiaKgM2: rotorUm * 1e-4);
      if (ratio > 10) {
        warn = '惯量比 ${ratio.toStringAsFixed(0)} 远超经验上限 10，'
            '伺服可能震荡/失步：请加减速机或换大转子惯量电机。';
      } else if (ratio > 3) {
        warn = '惯量比 ${ratio.toStringAsFixed(1)} 大于 3：可用，'
            '但动态性能一般，高精度场合建议加减速机。';
      }
    }
    setState(() {
      _warning = warn;
      _result = {
        '角加速度 α': '${alpha.toStringAsFixed(0)} rad/s²',
        '加速扭矩 J·α': '${tAccel.toStringAsFixed(3)} N·m',
        '峰值扭矩 T_peak': '${tPeak.toStringAsFixed(3)} N·m',
        '峰值功率 P': '${power.toStringAsFixed(2)} kW',
        '公式': 'T = T_load + J·(2πn/60)/t_a；P = T·n/9550',
      };
    });
  }

  void _calcRms() {
    final ts = [
      double.tryParse(_taT.text),
      double.tryParse(_tcT.text),
      double.tryParse(_tdT.text),
    ];
    final ds = [
      double.tryParse(_taS.text),
      double.tryParse(_tcS.text),
      double.tryParse(_tdS.text),
    ];
    if (ts.any((e) => e == null) || ds.any((e) => e == null || e < 0)) {
      setState(() => _rms = {'错误': '请完整填写三段扭矩与时间'});
      return;
    }
    final rms = QuickTools.rmsTorque(
        torques: ts.cast<double>(), durationsS: ds.cast<double>());
    final peakStr = _result?['峰值扭矩 T_peak'];
    final tPeak =
        peakStr == null ? null : double.tryParse(peakStr.split(' ').first);
    setState(() {
      _rms = {
        'RMS 等效扭矩 T_rms': '${rms.toStringAsFixed(3)} N·m',
        '公式': 'T_rms = √(ΣT²·t / Σt)',
        if (tPeak != null)
          '对比峰值 T_peak': '$tPeak N·m（连续运行电机额定扭矩需 ≥ T_rms）',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('伺服电机选型')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _card(context, '输入工况', [
            _field(_load, '负载扭矩 T_load', 'N·m（含摩擦/切削/重力折算）'),
            _field(_inertia, '折算到电机轴的负载惯量 J_load', '×10⁻⁴ kg·m²'),
            _field(_accel, '加减速时间 t_a', 's（伺服推荐 0.05~0.3）'),
            _field(_speed, '最高转速 n', 'rpm'),
            _field(_rotor, '电机转子惯量 J_motor（可选）', '×10⁻⁴ kg·m²，用于惯量比校核'),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _calc,
                icon: const Icon(Icons.bolt),
                label: const Text('开始计算'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => setState(() => _result = null),
              child: const Text('重置'),
            ),
          ]),
          const SizedBox(height: 14),
          if (_warning != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_warning!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer))),
                ]),
              ),
            ),
          if (_result != null) ...[
            FadeIn(
              key: ValueKey(_result.hashCode),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('选型结果',
                          style:
                              Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final e in _result!.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key,
                                  style: const TextStyle(fontSize: 12.5)),
                              Text(e.value,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        '选电机时按峰值扭矩×1.3 安全裕量、功率向上取整档【经验法则】。',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('RMS 等效扭矩校核（连续温升用）',
                        style: Theme.of(context).textTheme.titleSmall),
                    _field(_taT, '加速段扭矩', 'N·m'),
                    _field(_taS, '加速段时间', 's'),
                    _field(_tcT, '匀速段扭矩', 'N·m'),
                    _field(_tcS, '匀速段时间', 's'),
                    _field(_tdT, '减速段扭矩', 'N·m'),
                    _field(_tdS, '减速段时间', 's'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                        onPressed: _calcRms,
                        child: const Text('算 RMS')),
                    if (_rms != null) ...[
                      const SizedBox(height: 6),
                      for (final e in _rms!.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(e.key,
                                      style:
                                          const TextStyle(fontSize: 12))),
                              Text(e.value,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          TextField(
            controller: c,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(isDense: true, hintText: hint),
          ),
        ],
      ),
    );
  }
}
