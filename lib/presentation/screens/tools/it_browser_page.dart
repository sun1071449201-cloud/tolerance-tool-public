import 'package:flutter/material.dart';

class ITBrowserPage extends StatelessWidget {
  const ITBrowserPage({super.key});

  static const List<String> _grades = ['1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18'];
  static const List<String> _steps = ['≤3','3~6','6~10','10~18','18~30','30~50','50~80','80~120','120~180','180~250'];

  static const List<List<double>> _values = [
    [1,1,1.5,2,3,4,6,10,14,25,40,60,100,140,250,400,600,1000],
    [1,1.5,2.5,4,5,8,12,18,30,48,75,120,180,300,480,750,1200,1800],
    [1,1.5,2.5,4,6,9,15,22,36,58,90,150,220,360,580,900,1500,2200],
    [1.5,2,3,5,8,11,18,27,43,70,110,180,270,430,700,1100,1800,2700],
    [1.5,2.5,4,6,9,13,21,33,52,84,130,210,330,520,840,1300,2100,3300],
    [1.5,2.5,4,7,11,16,25,39,62,100,160,250,390,620,1000,1600,2500,3900],
    [2,3,5,8,13,19,30,46,74,120,190,300,460,740,1200,1900,3000,4600],
    [2.5,4,6,10,15,22,35,54,87,140,220,350,540,870,1400,2200,3500,5400],
    [3.5,5,8,12,18,25,40,63,100,160,250,400,630,1000,1600,2500,4000,6300],
    [4.5,7,10,14,20,29,46,72,115,185,290,460,720,1150,1850,2900,4600,7200],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('IT 公差值浏览')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 52, child: Text('尺寸↓', style: TextStyle(fontSize: 9))),
                for (var g = 0; g < _grades.length; g++)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      alignment: Alignment.center,
                      color: scheme.primaryContainer,
                      child: Text(_grades[g], style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            for (var s = 0; s < _steps.length; s++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    SizedBox(width: 52, child: Text(_steps[s], style: const TextStyle(fontSize: 9))),
                    for (var g = 0; g < _values[s].length; g++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _colorFor(_values[s][g]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            _fmtVal(_values[s][g]),
                            style: TextStyle(
                              fontSize: 8,
                              color: _values[s][g] > 500 ? Colors.white : scheme.onSurface,
                              fontWeight: _values[s][g] <= 10 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _legend('IT5-6: 研磨/精密磨'),
                _legend('IT7-8: 磨削/精铰'),
                _legend('IT9-10: 普通车铣'),
                _legend('IT11-12: 粗加工/冲压'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '单位 μm。数值为标准结构占位【待核对 ISO 286-1】。',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String text) {
    return Chip(label: Text(text, style: const TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact);
  }

  Color _colorFor(double um) {
    if (um <= 5) return const Color(0xFF1565C0);
    if (um <= 20) return const Color(0xFF42A5F5);
    if (um <= 50) return const Color(0xFF90CAF9);
    if (um <= 100) return const Color(0xFFFFF176);
    if (um <= 500) return const Color(0xFFFFAB91);
    return const Color(0xFFEF5350);
  }

  String _fmtVal(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }
}
