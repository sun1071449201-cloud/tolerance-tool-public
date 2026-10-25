import 'package:flutter/material.dart';

/// 工艺数据手册：硬度对照 / 摩擦系数 / 传动效率 / 扳手尺寸。
class ProcessDataPage extends StatelessWidget {
  const ProcessDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('工艺数据手册'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: '硬度对照'),
            Tab(text: '摩擦系数'),
            Tab(text: '传动效率'),
            Tab(text: '扳手尺寸'),
          ]),
        ),
        body: TabBarView(children: [
          _HardnessTab(),
          _FrictionTab(),
          _EfficiencyTab(),
          _WrenchTab(),
        ]),
      ),
    );
  }
}

// ==================== 硬度对照 ====================
class _HardnessTab extends StatelessWidget {
  // 近似换算【待核对 GB/T 1172 / ASTM E140】
  static const List<List<String>> _rows = [
    ['HRC 20', '226', '238', '退火/正火态'],
    ['HRC 25', '253', '266', '调质态下限'],
    ['HRC 30', '286', '302', '一般调质'],
    ['HRC 35', '331', '345', '轴类常用'],
    ['HRC 40', '385', '392', '齿轮齿面下限'],
    ['HRC 45', '443', '446', '齿轮齿面常用'],
    ['HRC 50', '513', '513', '淬火+低温回火'],
    ['HRC 55', '—', '595', '轴承/凸轮'],
    ['HRC 60', '—', '697', '量具/滚动体'],
    ['HRC 62', '—', '739', '轴承套圈'],
    ['HRC 65', '—', '832', '硬质合金层'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _note(context,
            'HRC 适用于 20~67 范围；HB 适用于 ≤650；HV 通用。'
            '换算是近似关系【待核对 GB/T 1172】，验收以图纸标注的硬度制式为准。\n'
            'QC 常见点：HRC 与 HRB 不能直接换算；'
            '表面渗碳件测表面 HRC 需磨去脱碳层。'),
        _table(context, ['洛氏 HRC', '布氏 HB', '维氏 HV', '典型场景'], _rows),
      ],
    );
  }
}

// ==================== 摩擦系数 ====================
class _FrictionTab extends StatelessWidget {
  static const List<List<String>> _rows = [
    ['钢 — 钢（干）', '0.15~0.2', '0.1~0.12', '一般机械'],
    ['钢 — 铸铁', '0.2~0.3', '0.12~0.16', '机床床身'],
    ['钢 — 青铜', '0.15~0.2', '0.1~0.15', '蜗轮/轴瓦'],
    ['钢 — PTFE', '0.04~0.1', '0.04', '自润滑垫片'],
    ['钢 — POM', '0.1~0.15', '0.08', '塑料齿轮'],
    ['铸铁 — 铸铁', '0.15~0.25', '0.12', '导轨滑动副'],
    ['橡胶 — 混凝土', '0.6~0.8', '0.5', '防滑/减振'],
    ['淬火钢 — 青铜', '—', '0.08', '油润滑轴承'],
    ['螺栓螺纹（等效）', '—', 'K≈0.2', '扭矩预紧换算'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _note(context,
            '干摩擦典型值【待核对】；有润滑时静摩擦约为干态的 1/2~1/3。'
            '计算夹紧力/自锁/打滑时按不利工况取小值。'),
        _table(context, ['摩擦副', '静摩擦 μs', '动摩擦 μk', '典型应用'], _rows),
      ],
    );
  }
}

// ==================== 传动效率 ====================
class _EfficiencyTab extends StatelessWidget {
  static const List<List<String>> _rows = [
    ['平带传动', '0.95~0.98', '高速远距'],
    ['V 带传动', '0.94~0.96', '单根；多根按根数'],
    ['同步带', '0.96~0.98', '无滑差'],
    ['圆柱齿轮（油浴）', '0.96~0.98', '每级 8 级精度'],
    ['锥齿轮', '0.94~0.97', '每级'],
    ['蜗杆 单头', '0.70~0.75', '自锁型更低'],
    ['蜗杆 双头', '0.75~0.82', ''],
    ['蜗杆 四头', '0.82~0.90', ''],
    ['链传动', '0.95~0.97', '开式取低值'],
    ['滚动轴承副', '0.99', '每对'],
    ['滑动丝杠', '0.30~0.50', '梯形螺纹'],
    ['滚珠丝杠', '0.90~0.95', '预压后略降'],
    ['行星减速器 单级', '0.95~0.98', '多级相乘'],
    ['谐波减速器', '0.70~0.90', '随转速/温度变化'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _note(context,
            '总效率 = 各级效率连乘。例：电机→V带(0.95)→齿轮一级(0.97)→滚动轴承(0.99) '
            '≈ 0.91【待核对 机械设计手册】。'),
        _table(context, ['传动形式', '效率 η', '说明'], _rows),
      ],
    );
  }
}

// ==================== 扳手尺寸 ====================
class _WrenchTab extends StatelessWidget {
  // GB/T 5782 六角头对边宽 S；GB/T 70 内六角扳手规格
  static const List<List<String>> _rows = [
    ['M3', '5.5', '2.5'],
    ['M4', '7', '3'],
    ['M5', '8', '4'],
    ['M6', '10', '5'],
    ['M8', '13', '6'],
    ['M10', '17', '8'],
    ['M12', '19', '10'],
    ['M14', '22', '—'],
    ['M16', '24', '14'],
    ['M18', '27', '—'],
    ['M20', '30', '17'],
    ['M22', '34', '—'],
    ['M24', '36', '19'],
    ['M27', '41', '—'],
    ['M30', '46', '—'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _note(context,
            '对边宽 S 为六角头螺栓标准值【待核对 GB/T 5782】；'
            '法兰螺栓/非标头型可能不同。内六角列为 GB/T 70 圆柱头螺钉对应扳手。'),
        _table(context, ['螺纹', '六角头 S (mm)', '内六角 (mm)'], _rows),
      ],
    );
  }
}

// ==================== 公共组件 ====================
Widget _note(BuildContext context, String text) {
  final scheme = Theme.of(context).colorScheme;
  return Card(
    color: scheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(height: 1.5)),
    ),
  );
}

Widget _table(BuildContext context, List<String> headers,
    List<List<String>> rows) {
  final scheme = Theme.of(context).colorScheme;
  return Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(scheme.surfaceContainerHighest),
        columnSpacing: 14,
        columns: [
          for (final h in headers)
            DataColumn(
                label: Text(h, style: const TextStyle(fontSize: 11))),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              for (var i = 0; i < r.length; i++)
                DataCell(Text(r[i],
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            i == 0 ? FontWeight.bold : FontWeight.normal,
                        color: scheme.onSurface))),
            ]),
        ],
      ),
    ),
  );
}
