import 'package:flutter/material.dart';

import '../../../domain/services/quick_tools.dart';
import '../../widgets/calc_widgets.dart';

/// 计量检测计算：CPK / 正弦规 / 螺纹三针 / 锥度与莫氏。
class MetrologyPage extends StatelessWidget {
  const MetrologyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('计量检测计算'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'CPK 过程能力'),
            Tab(text: '正弦规量块'),
            Tab(text: '三针测量 M'),
            Tab(text: '锥度·莫氏'),
            Tab(text: '螺纹通止规'),
          ]),
        ),
        body: TabBarView(children: [
          _CpkTab(),
          _SineTab(),
          _WireTab(),
          _TaperTab(),
          _GaugeTab(),
        ]),
      ),
    );
  }
}

// ==================== CPK ====================
class _CpkTab extends StatefulWidget {
  @override
  State<_CpkTab> createState() => _CpkTabState();
}

class _CpkTabState extends State<_CpkTab> {
  final _usl = TextEditingController(text: '10.1');
  final _lsl = TextEditingController(text: '9.9');
  final _vals = TextEditingController(
      text: '10.02, 10.04, 9.98, 10.00, 9.96, 10.05, 9.97, 10.03');

  Map<String, String>? _rows;
  String? _judge;
  Color? _judgeColor;
  List<double>? _histXs;
  double? _histUsl, _histLsl;

  void _calc() {
    final usl = double.tryParse(_usl.text);
    final lsl = double.tryParse(_lsl.text);
    final tokens = _vals.text.split(RegExp(r'[\s,;，；]+'))
        .where((t) => t.trim().isNotEmpty).toList();
    final xs = [for (final t in tokens) double.tryParse(t)]
        .whereType<double>()
        .toList();
    if (usl == null || lsl == null || usl <= lsl || xs.length < 5) {
      setState(() => _rows = {'错误': 'USL 须大于 LSL，且测量值 ≥5 个'});
      return;
    }
    final n = xs.length;
    final mean = xs.reduce((a, b) => a + b) / n;
    final s = QuickTools.sampleStdev(xs);
    final cp = QuickTools.cp(usl: usl, lsl: lsl, stdev: s);
    final cpk = QuickTools.cpk(
        usl: usl, lsl: lsl, mean: mean, stdev: s);
    final ca = QuickTools.ca(usl: usl, lsl: lsl, mean: mean);

    String j;
    Color c;
    if (cpk >= 1.67) {
      j = 'A 级以上：过程能力充足，可考虑放宽抽检';
      c = Colors.green;
    } else if (cpk >= 1.33) {
      j = 'B 级：能力充分（汽车行业通常要求 ≥1.33）';
      c = Colors.blue;
    } else if (cpk >= 1.0) {
      j = 'C 级：勉强合格，需加强监控、防出界';
      c = Colors.orange;
    } else {
      j = 'D 级：能力不足，先排查偏心(Ca)再降波动(s)';
      c = Colors.red;
    }

    setState(() {
      _rows = {
        '样本数 n': '$n',
        '均值 μ': mean.toStringAsFixed(4),
        '样本标准差 s（n−1）': s.toStringAsFixed(4),
        'Ca 偏心度': '${ca.toStringAsFixed(3)}（|Ca|≤0.1 较好）',
        'Cp = (USL−LSL)/6s': cp.toStringAsFixed(3),
        'Cpk = min(USL−μ, μ−LSL)/3s': cpk.toStringAsFixed(3),
      };
      _judge = j;
      _judgeColor = c;
      _histXs = xs;
      _histUsl = usl;
      _histLsl = lsl;
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
                CalcField(_usl, '规格上限 USL', 'mm'),
                CalcField(_lsl, '规格下限 LSL', 'mm'),
                const SizedBox(height: 8),
                const Text('测量值（≥5 个）',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: _vals,
                  minLines: 3,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '空格 / 逗号 / 换行分隔，可直接从 Excel 粘贴',
                    alignLabelWithHint: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _calc,
            icon: const Icon(Icons.bolt),
            label: const Text('计算 CPK')),
        const SizedBox(height: 12),
        if (_rows != null) CalcResult(rows: _rows!),
        if (_histXs != null && _histUsl != null && _histLsl != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('分布直方图', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 140,
                      child: CustomPaint(
                        painter: _HistogramPainter(
                            xs: _histXs!, usl: _histUsl!, lsl: _histLsl!),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('蓝柱=数据分布，红/绿线=USL/LSL，阴影=规格区',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ),
          ),
        if (_judge != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Card(
              color: _judgeColor!.withOpacity(0.12),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(_judge!,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _judgeColor)),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'CPK 用组内样本标准差（n−1）估算【常见做法；PPK 用全部数据、'
          '按客户要求区分，待核对客户 SPC 手册】。判级界限 1.33/1.67 为通用经验值，'
          '以客户标准为准。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ==================== 正弦规 ====================
class _SineTab extends StatefulWidget {
  @override
  State<_SineTab> createState() => _SineTabState();
}

class _SineTabState extends State<_SineTab> {
  String _mode = '角度 → 量块高度';
  final _lCtrl = TextEditingController(text: '100');
  final _aCtrl = TextEditingController(text: '15');
  final _hCtrl = TextEditingController(text: '25');

  static const _morse = [
    ['莫氏 0', '1:19.212', '9.045'],
    ['莫氏 1', '1:20.047', '12.065'],
    ['莫氏 2', '1:20.020', '17.780'],
    ['莫氏 3', '1:19.922', '23.825'],
    ['莫氏 4', '1:19.254', '31.267'],
    ['莫氏 5', '1:19.002', '44.399'],
    ['莫氏 6', '1:19.180', '63.348'],
  ];

  @override
  void dispose() {
    for (final c in [_lCtrl, _aCtrl, _hCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = double.tryParse(_lCtrl.text) ?? 0;
    final a = double.tryParse(_aCtrl.text);
    final h = double.tryParse(_hCtrl.text);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '角度 → 量块高度', label: Text('角度→高度')),
            ButtonSegment(value: '量块高度 → 角度', label: Text('高度→角度')),
          ],
          selected: {_mode},
          onSelectionChanged: (v) => setState(() => _mode = v.first),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CalcField(_lCtrl, '正弦规两滚柱中心距 L', '标准 100 或 200 mm'),
                if (_mode == '角度 → 量块高度')
                  CalcField(_aCtrl, '需垫角度 θ（锥体测量=锥角之半）', '°')
                else
                  CalcField(_hCtrl, '量块高度 H', 'mm'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (_mode == '角度 → 量块高度' && l > 0 && a != null)
          CalcResult(rows: {
            '量块高度 H = L·sinθ':
                '${QuickTools.sineGaugeHeight(rollDistanceMm: l, angleDeg: a).toStringAsFixed(3)} mm',
            '公式': 'H = L·sin θ',
          })
        else if (l > 0 && h != null)
          CalcResult(rows: {
            '角度 θ = arcsin(H/L)':
                '${QuickTools.angleFromSineHeight(rollDistanceMm: l, heightMm: h).toStringAsFixed(4)}°',
            '锥体全角': '2θ = ${(QuickTools.angleFromSineHeight(rollDistanceMm: l, heightMm: h) * 2).toStringAsFixed(4)}°',
          }),
        const SizedBox(height: 8),
        Text(
          '使用要点：正弦规+量块+杠杆表组合测锥度，'
          'θ 垫的是锥角的一半；两端量块合成一组，'
          '以千分表在全长两端读数差判锥角偏差。'
          'L=100/200 的正弦规对应【待核对 GB/T 22526】。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('莫氏锥度速查【待核对 GB/T 1443】',
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  for (final r in _morse)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(children: [
                        SizedBox(
                            width: 64,
                            child: Text(r[0],
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold))),
                        Expanded(
                            child: Text('锥度 ${r[1]}',
                                style: const TextStyle(fontSize: 11.5))),
                        Text('大端 Ø${r[2]}',
                            style: const TextStyle(fontSize: 11.5)),
                      ]),
                    ),
                ]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ==================== 三针测量 ====================
class _WireTab extends StatefulWidget {
  @override
  State<_WireTab> createState() => _WireTabState();
}

class _WireTabState extends State<_WireTab> {
  final _dCtrl = TextEditingController(text: '6');
  final _pCtrl = TextEditingController(text: '1');
  final _wCtrl = TextEditingController(text: '');

  @override
  void dispose() {
    for (final c in [_dCtrl, _pCtrl, _wCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = double.tryParse(_dCtrl.text);
    final p = double.tryParse(_pCtrl.text);
    final w = double.tryParse(_wCtrl.text);
    final ok = d != null && p != null && d > 0 && p > 0;
    final m = ok
        ? QuickTools.threadMeasureOverPins(
            nominalDiaMm: d, pitchMm: p, wireDiaMm: w)
        : null;
    final d2 = ok
        ? QuickTools.metricBasicPitchDia(
            nominalDiaMm: d, pitchMm: p)
        : null;
    final bestW = ok ? 0.577350 * p : null;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('输入（公制 60° 牙型角）',
                    style: Theme.of(context).textTheme.titleSmall),
                CalcField(_dCtrl, '螺纹公称直径 d', 'mm'),
                CalcField(_pCtrl, '螺距 P', 'mm'),
                CalcField(_wCtrl, '量针直径 D（留空=最佳针径）', 'mm'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (ok)
          CalcResult(rows: {
            '基本中径 d₂ = d − 0.6495·P':
                '${d2!.toStringAsFixed(4)} mm',
            '最佳量针 D = 0.5774·P':
                '${bestW!.toStringAsFixed(3)} mm',
            '三针测量基本 M 值': '${m!.toStringAsFixed(4)} mm',
            '公式': 'M = d₂ + 3D − 0.8660·P',
          }),
        const SizedBox(height: 8),
        Text(
          '用法：三针+外径千分尺测得 M 实测值，与 M 基本±中径公差折算比较，'
          '判定中径合格性（QC 进料检验螺纹塞规替代法的精确手段）。'
          '梯形螺纹 30° 牙型角、英制 55° 牙型角公式不同【本页仅公制 M/P 系列，待核对】。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ==================== 锥度 ====================
class _TaperTab extends StatefulWidget {
  @override
  State<_TaperTab> createState() => _TaperTabState();
}

class _TaperTabState extends State<_TaperTab> {
  final _big = TextEditingController(text: '20');
  final _small = TextEditingController(text: '18');
  final _len = TextEditingController(text: '40');

  @override
  void dispose() {
    for (final c in [_big, _small, _len]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bd = double.tryParse(_big.text);
    final sd = double.tryParse(_small.text);
    final ln = double.tryParse(_len.text);
    final info = (bd != null && sd != null && ln != null)
        ? QuickTools.taperInfo(bigDiaMm: bd, smallDiaMm: sd, lengthMm: ln)
        : null;

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
                CalcField(_big, '大端直径 D', 'mm'),
                CalcField(_small, '小端直径 d', 'mm'),
                CalcField(_len, '锥面轴向长度 L', 'mm'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (info != null)
          info[0] > 0
              ? CalcResult(rows: {
                  '锥度 1 : K': info[0].toStringAsFixed(3),
                  '半角 α = arctan((D−d)/2L)':
                      '${info[1].toStringAsFixed(4)}°',
                  '全角 2α': '${info[2].toStringAsFixed(4)}°',
                  '公式': 'K = L/(D−d)',
                })
              : const CalcResult(rows: {'错误': 'D 须大于 d，L 须大于 0'}),
        const SizedBox(height: 8),
        Text(
          '图纸标注锥度 1:K 时：大端−小端 = L/K。'
          '如 1:10 锥、长 50 → 直径差 5 mm。'
          '测锥度配套用正弦规 Tab：垫半角 α，看全长读数差。',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// CPK 直方图：数据分布蓝柱 + USL/LSL 规格线 + 公差带底色。
class _HistogramPainter extends CustomPainter {
  _HistogramPainter({
    required this.xs,
    required this.usl,
    required this.lsl,
  });

  final List<double> xs;
  final double usl;
  final double lsl;

  @override
  void paint(Canvas canvas, Size size) {
    if (xs.isEmpty || usl <= lsl) return;
    var lo = lsl, hi = usl;
    for (final x in xs) {
      if (x < lo) lo = x;
      if (x > hi) hi = x;
    }
    final pad = (hi - lo) * 0.12 + 1e-9;
    lo -= pad;
    hi += pad;
    const bins = 12;
    final counts = List<int>.filled(bins, 0);
    final w = (hi - lo) / bins;
    var maxCount = 1;
    for (final x in xs) {
      var b = ((x - lo) / w).floor();
      if (b >= bins) b = bins - 1;
      if (b < 0) b = 0;
      counts[b]++;
      if (counts[b] > maxCount) maxCount = counts[b];
    }

    final paint = Paint();
    final xL = _xOf(lsl, lo, hi, size.width);
    final xU = _xOf(usl, lo, hi, size.width);
    // 规格区浅绿底，区外浅红底
    paint.color = const Color(0x144CAF50);
    canvas.drawRect(Rect.fromLTRB(xL, 0, xU, size.height), paint);
    if (xL > 0) {
      paint.color = const Color(0x10EF5350);
      canvas.drawRect(Rect.fromLTRB(0, 0, xL, size.height), paint);
    }
    if (xU < size.width) {
      paint.color = const Color(0x10EF5350);
      canvas.drawRect(Rect.fromLTRB(xU, 0, size.width, size.height), paint);
    }

    final barW = size.width / bins;
    for (var i = 0; i < bins; i++) {
      if (counts[i] == 0) continue;
      final h = size.height * 0.86 * counts[i] / maxCount;
      paint.color = const Color(0xFF42A5F5);
      canvas.drawRect(
        Rect.fromLTRB(
            i * barW + 1.5, size.height - h, (i + 1) * barW - 1.5, size.height),
        paint,
      );
    }

    _specLine(canvas, size, xL, 'LSL', const Color(0xFF2E7D32));
    _specLine(canvas, size, xU, 'USL', const Color(0xFFC62828));
  }

  double _xOf(double v, double lo, double hi, double width) {
    final r = (v - lo) / (hi - lo);
    return r.clamp(0.0, 1.0) * width;
  }

  void _specLine(Canvas canvas, Size size, double x, String label, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    final tp = TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
    tp.paint(canvas, Offset(lx, 1));
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter old) =>
      old.xs != xs || old.usl != usl || old.lsl != lsl;
}

// ==================== 螺纹通止规 ====================
class _GaugeTab extends StatelessWidget {
  static const List<List<String>> _steps = [
    ['1', '清洁', '擦净工件与量规牙面，喷轻油防拉毛'],
    ['2', '通规 T', '应能靠自身重量+轻微旋力顺畅通过全螺纹长度'],
    ['3', '止规 Z', '只允许旋入 ≤2 圈且不得通过（用力拧不算）'],
    ['4', '判定', 'T 通 + Z 止 = 合格；T 不通 = 中径过小；Z 过 = 中径过大'],
    ['5', '记录', '记录规号与判定结果；规具有效期内使用'],
  ];

  static const List<List<String>> _traps = [
    ['只用通规不检止规', '止规超差照样报废下游——两规缺一不可'],
    ['止规用力硬拧', '把"勉强进 2 圈"拧成"通过"，误收超差品'],
    ['量规超期未校验', '通规磨损变小会误收，止规磨损变大也会误收'],
    ['锈屑当牙型', '铁屑垫高牙面，通规不过其实是脏不是小'],
    ['内外规混用', '塞规检内螺纹、环规检外螺纹，拿错方向全盘错'],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        listCard(context, '五步判定流程', _steps, Icons.rule),
        const SizedBox(height: 10),
        listCard(context, '五大误判现场', _traps, Icons.warning_amber_rounded),
        const SizedBox(height: 10),
        Card(
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              '判定依据：通规检"最大实体"（能装），止规检"最小实体"（不松）。'
              '中径数值仲裁用三针法（本页"三针测量 M"Tab）。'
              '量规校验周期与判定细节以 GB/T 3934 及客户标准为准【待核对】。',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget listCard(BuildContext context, String title,
      List<List<String>> rows, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 6),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 22,
                        child: Text(r[0],
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary))),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r[1],
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 1),
                            Text(r[2],
                                style: const TextStyle(fontSize: 11.5)),
                          ]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
