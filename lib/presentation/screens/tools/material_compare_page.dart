import 'package:flutter/material.dart';

/// 材料性能对比选型器：一屏对比常用材料的密度/强度/弹性模量/线膨胀/导热。
class MaterialComparePage extends StatefulWidget {
  const MaterialComparePage({super.key});

  @override
  State<MaterialComparePage> createState() => _MaterialComparePageState();
}

class _MaterialComparePageState extends State<MaterialComparePage> {
  int _sortCol = 3; // 默认按屈服强度排
  bool _asc = false;

  static const _materials = <List<dynamic>>[
    ['45 钢', '碳钢', 7.85, 355, 600, 207, 11.5, 50, '调质 HB220~250'],
    ['40Cr', '合金钢', 7.85, 785, 980, 207, 11.5, 50, '油淬变形小'],
    ['GCr15', '轴承钢', 7.81, 1700, 2000, 210, 11.5, 50, '淬硬 HRC58~62'],
    ['Q235', '碳钢', 7.85, 235, 400, 200, 11.5, 50, '焊接结构'],
    ['SUS304', '不锈钢', 7.93, 205, 520, 193, 16.5, 16, '通用耐蚀'],
    ['SUS316', '不锈钢', 7.98, 240, 550, 193, 16.0, 16, '加钼耐氯'],
    ['SUS440C', '不锈钢', 7.62, 1650, 1900, 200, 10.5, 24, '可淬硬'],
    ['6061-T6', '铝合金', 2.70, 275, 310, 69, 23.6, 167, '万能结构铝'],
    ['7075-T651', '铝合金', 2.81, 505, 570, 72, 23.4, 130, '高强度铝'],
    ['5052-H32', '铝合金', 2.68, 193, 230, 70, 23.8, 138, '钣金折弯首选'],
    ['H62 黄铜', '铜合金', 8.50, 280, 400, 105, 20.5, 109, '易切削'],
    ['T2 紫铜', '纯铜', 8.90, 70, 200, 117, 17.0, 398, '导电导热极佳'],
    ['TC4 钛', '钛合金', 4.43, 880, 950, 114, 8.6, 7, '轻且强/导热差'],
    ['POM', '塑料', 1.41, 62, 68, 2.8, 85, 0.3, '自润滑齿轮'],
    ['PEEK', '塑料', 1.30, 97, 100, 3.6, 47, 0.25, '耐高温 250℃'],
  ];

  List<List<dynamic>> get _sorted {
    final list = [..._materials];
    list.sort((a, b) => _asc
        ? (a[_sortCol] as num).compareTo(b[_sortCol] as num)
        : (b[_sortCol] as num).compareTo(a[_sortCol] as num));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = _sorted;

    return Scaffold(
      appBar: AppBar(
        title: const Text('材料性能对比选型'),
        actions: [
          IconButton(
            tooltip: '排序说明',
            icon: const Icon(Icons.info_outline, size: 18),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('怎么用这张表'),
                content: const Text(
                    '点击列头可排序。\n\n选材三步：\n'
                    '① 强度/刚度够不够？→ 看屈服和 E\n'
                    '② 重不重？→ 看密度（铝 2.7 vs 钢 7.85）\n'
                    '③ 环境适应？→ 线膨胀（温变尺寸漂移）+ 导热（散热）\n\n'
                    '数值为典型参考值【待核对】。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('知道了'))
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(scheme.surfaceContainerHighest),
            columnSpacing: 16,
            columns: [
              const DataColumn(label: Text('材料')),
              const DataColumn(label: Text('类别')),
              _numCol('密度\n(g/cm³)', 2),
              _numCol('屈服\n(MPa)', 3),
              _numCol('抗拉\n(MPa)', 4),
              _numCol('E 模量\n(GPa)', 5),
              _numCol('线膨胀\n(μm/m·°C)', 6),
              _numCol('导热\n(W/m·K)', 7),
              const DataColumn(label: Text('备注')),
            ],
            rows: [
              for (final m in rows)
                DataRow(cells: [
                  DataCell(Text(m[0] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(m[1] as String,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant))),
                  DataCell(Text(_fmt(m[2]))),
                  DataCell(Text(_fmt(m[3]),
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold))),
                  DataCell(Text(_fmt(m[4]))),
                  DataCell(Text(_fmt(m[5]))),
                  DataCell(Text(_fmt(m[6]))),
                  DataCell(Text(_fmt(m[7]))),
                  DataCell(Text(m[8] as String,
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant))),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  DataColumn _numCol(String label, int idx) {
    return DataColumn(
      label: Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11)),
      numeric: true,
      onSort: (_, asc) => setState(() {
        _sortCol = idx;
        _asc = asc;
      }),
    );
  }

  String _fmt(dynamic v) {
    if (v is double) return v.toStringAsFixed(1);
    return v.toString();
  }
}
