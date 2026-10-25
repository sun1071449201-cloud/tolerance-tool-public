import 'package:flutter/material.dart';

/// 标准件选型库：螺栓/轴承/键/销/O 型圈规格速查。
class PartsLibraryPage extends StatelessWidget {
  const PartsLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('标准件选型库'),
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: '螺栓扭矩'),
            Tab(text: '深沟球轴承'),
            Tab(text: '平键'),
            Tab(text: '圆柱销'),
            Tab(text: 'O 型圈'),
            Tab(text: '轴用卡簧'),
            Tab(text: '孔用卡簧'),
            Tab(text: '垫圈'),
          ]),
        ),
        body: TabBarView(children: [
          _BoltTable(),
          _BearingTable(),
          _KeyTable(),
          _PinTable(),
          _OringTable(),
          _CirclipTable(),
          _HoleCirclipTable(),
          _WasherTable(),
        ]),
      ),
    );
  }
}

// ==================== 螺栓 ====================
class _BoltTable extends StatelessWidget {
  static const _data = [
    ('M3', 1.2, 2.5, 5.5, 3.0, 6.5, 2.4, 1.1),
    ('M4', 2.8, 5.3, 7.0, 4.0, 8.0, 3.2, 1.4),
    ('M5', 5.5, 10, 8.5, 5.0, 9.5, 4.0, 1.7),
    ('M6', 9.5, 18, 10.0, 6.0, 11.0, 4.8, 2.0),
    ('M8', 23, 44, 13.0, 8.0, 14.0, 6.4, 2.7),
    ('M10', 46, 88, 16.0, 10.0, 17.5, 8.0, 3.4),
    ('M12', 80, 150, 18.5, 12.0, 20.0, 9.6, 4.1),
    ('M16', 200, 370, 24.0, 16.0, 26.0, 12.8, 5.4),
    ('M20', 390, 720, 30.0, 20.0, 32.0, 16.0, 6.8),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '⚙️ 扭矩为 8.8 级干态近似值【待核对】；10.9 级 ×1.4，12.9 级 ×1.7。\n'
              '通孔=中等装配 GB/T 5277；底孔=钢件攻丝。',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
        _table(context, [
          '规格', '扭矩 N·m\n8.8级', '通孔\n(中等)', '沉孔径\n(内六角)', '底孔\n(攻丝)',
        ], _data.map((r) => [r.$1, '${r.$2}', '${r.$3}', '${r.$4}', '${r.$6}']).toList()),
      ],
    );
  }
}

// ==================== 轴承 ====================
class _BearingTable extends StatelessWidget {
  static const _data = [
    ('6000', 10, 26, 8, 4.5, 15000),
    ('6001', 12, 28, 8, 5.1, 14000),
    ('6002', 15, 32, 9, 5.6, 12000),
    ('6003', 17, 35, 10, 6.0, 11000),
    ('6200', 10, 30, 9, 5.1, 15000),
    ('6201', 12, 32, 10, 7.0, 13000),
    ('6202', 15, 35, 11, 7.7, 12000),
    ('6203', 17, 40, 12, 9.5, 11000),
    ('6204', 20, 47, 14, 12.8, 10000),
    ('6205', 25, 52, 15, 14.0, 9000),
    ('6303', 17, 47, 14, 13.5, 11000),
    ('6304', 20, 52, 15, 15.9, 9500),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _table(context, [
          '代号', '内径 d\n(mm)', '外径 D\n(mm)', '宽度 B\n(mm)', '额定动载荷\nC (kN)', '极限转速\n脂 (rpm)',
        ], _data.map((r) => [r.$1, '${r.$2}', '${r.$3}', '${r.$4}', '${r.$5}', '${r.$6}']).toList()),
        const SizedBox(height: 8),
        Text(
          'Cr=径向额定动载荷【待核对，查厂家手册为准】。\n'
          '配轴 k5/j5（内圈转），配孔 H7（外圈不动）。\n'
          'dn<20万 用脂润滑（填充 1/2~2/3 腔体）。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 平键 ====================
class _KeyTable extends StatelessWidget {
  static const _data = [
    ('>8~10', 3, 3, 1.8, 'M3'),
    ('>10~12', 4, 4, 2.5, 'M4'),
    ('>12~17', 5, 5, 3.0, 'M5'),
    ('>17~22', 6, 6, 3.5, 'M6'),
    ('>22~30', 8, 7, 4.0, 'M8'),
    ('>30~38', 10, 8, 5.0, 'M10'),
    ('>38~44', 12, 8, 5.0, 'M12'),
    ('>44~50', 14, 9, 5.5, 'M14'),
    ('>50~58', 16, 10, 6.0, 'M16'),
    ('>58~65', 18, 11, 7.0, 'M18'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _table(context, [
          '轴径\n(mm)', '键宽 b\n(mm)', '键高 h\n(mm)', '轴槽深\nt₁ (mm)', '推荐螺钉',
        ], _data.map((r) => [r.$1, '${r.$2}', '${r.$3}', '${r.$4}', r.$5]).toList()),
        const SizedBox(height: 8),
        Text(
          '平键按 GB/T 1096【数值待核对】。\n'
          'A 型圆头（最常用）、B 型方头、C 型单圆头。\n'
          '键宽公差：轴槽 N9，毂槽 JS9（一般连接）。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 圆柱销 ====================
class _PinTable extends StatelessWidget {
  static const _data = [
    ('2', 6, 'm6/h8'),
    ('2.5', 8, 'm6/h8'),
    ('3', 10, 'm6/h8'),
    ('4', 14, 'm6/h8'),
    ('5', 18, 'm6/h8'),
    ('6', 22, 'm6/h8'),
    ('8', 28, 'm6/h8'),
    ('10', 35, 'm6/h8'),
    ('12', 42, 'm6/h8'),
    ('16', 55, 'm6/h8'),
    ('20', 70, 'm6/h8'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _table(context, [
          '公称直径\n(mm)', '常用长度\n(mm)', '公差带',
        ], _data.map((r) => [r.$1, '${r.$2}', r.$3]).toList()),
        const SizedBox(height: 8),
        Text(
          '圆柱销 GB/T 119.1【待核对】。\n'
          '定位通常两销：一圆一菱（削边），方向错开 90°。\n'
          '销孔配作（铰刀铰孔），拆装会伤孔壁。\n'
          '需反复拆装 → 改圆锥销 GB/T 117（1:50 锥度自锁）。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== O 型圈 ====================
class _OringTable extends StatelessWidget {
  static const _data = [
    ('1.5', '静密封 15~25%', '槽宽 2.0', '小尺寸精密'),
    ('1.8', '静密封 15~25%', '槽宽 2.4', '液压标准'),
    ('2.0', '静/动 15/12%', '槽宽 2.7', '通用'),
    ('2.5', '静/动 15/12%', '槽宽 3.3', '气动'),
    ('3.0', '静/动 15/12%', '槽宽 4.0', '液压高压'),
    ('3.5', '静密封 15~25%', '槽宽 4.7', '大型法兰'),
    ('4.0', '静密封 15~25%', '槽宽 5.3', '真空/大尺寸'),
    ('5.0', '静密封 15~25%', '槽宽 6.7', '特大'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _table(context, [
          '线径 d\n(mm)', '压缩率', '槽宽 b\n(mm)', '适用',
        ], _data.map((r) => [r.$1, r.$2, r.$3, r.$4]).toList()),
        const SizedBox(height: 8),
        Text(
          '槽深 = 线径 − 压缩量。例：线径 2.0，压缩率 20% → 槽深 1.6。\n'
          '材质选型：NBR 耐油(-30~100℃)；FKM 耐温(-20~200℃)不耐胺；\n'
          'EPDM 耐水(-50~130℃) 但遇油膨胀！【GB/T 3452 待核对】',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 卡簧槽（轴用弹性挡圈 GB/T 894） ====================
class _CirclipTable extends StatelessWidget {
  static const List<List<String>> _data = [
    ['8', '7.4', '0.9', '0.6', '2'],
    ['10', '9.2', '1.0', '0.6', '2'],
    ['12', '11.0', '1.0', '0.8', '2'],
    ['15', '13.8', '1.0', '1.0', '2'],
    ['17', '15.7', '1.2', '1.0', '2.5'],
    ['20', '18.5', '1.2', '1.0', '2.5'],
    ['25', '23.5', '1.2', '1.3', '2.5'],
    ['30', '28.0', '1.5', '1.3', '3'],
    ['35', '32.8', '1.5', '1.6', '3'],
    ['40', '37.5', '1.7', '1.6', '3'],
    ['45', '42.5', '1.7', '1.6', '3.8'],
    ['50', '47.0', '2.0', '2.0', '3.8'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _table(context, [
          '轴径 d\n(mm)', '沟槽直径\n(mm)', '沟槽宽 b\n(mm)', '沟槽深 t\n(mm)', '倒角\n(mm)',
        ], _data),
        const SizedBox(height: 8),
        Text(
          '轴用弹性挡圈 GB/T 894【沟槽尺寸待核对】。\n'
          '孔用弹性挡圈为 GB/T 893（沟槽在孔壁上）。\n'
          'QC 检查点：挡圈装配后应完全嵌入沟槽、'
          '开口间隙不超过规定值；沟槽毛刺会导致挡圈脱落。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 孔用卡簧（GB/T 893） ====================
class _HoleCirclipTable extends StatelessWidget {
  static const List<List<String>> _data = [
    ['8', '8.8', '0.9', '0.6'],
    ['10', '10.8', '1.0', '0.8'],
    ['12', '13.0', '1.0', '0.8'],
    ['15', '16.2', '1.0', '1.0'],
    ['17', '18.3', '1.2', '1.0'],
    ['20', '21.5', '1.2', '1.0'],
    ['25', '26.9', '1.3', '1.3'],
    ['30', '32.1', '1.5', '1.3'],
    ['35', '37.8', '1.7', '1.6'],
    ['40', '43.5', '1.7', '1.6'],
    ['45', '48.5', '2.0', '1.6'],
    ['50', '54.0', '2.2', '2.0'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _table(context, [
          '孔径 D\n(mm)', '沟槽直径 D₂\n(mm)', '沟槽宽 m\n(mm)', '沟槽深 t\n(mm)',
        ], _data),
        const SizedBox(height: 8),
        Text(
          '孔用弹性挡圈 GB/T 893【沟槽尺寸待核对】——'
          '挡圈装在孔壁沟槽里，承受轴向力把轴承等挡在孔内。\n'
          '与轴用（GB/T 894）区别：轴用槽在轴上、孔用槽在孔上，'
          '孔用挡圈是张开的（钳子往外撑），轴用是收拢的。\n'
          '轴承两侧双挡圈固定最常见：外圈孔用 + 内圈轴用。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 垫圈（平垫圈 GB/T 97.1） ====================
class _WasherTable extends StatelessWidget {
  static const List<List<String>> _data = [
    ['M3', '3.2', '7', '0.5'],
    ['M4', '4.3', '9', '0.8'],
    ['M5', '5.3', '10', '1.0'],
    ['M6', '6.4', '12', '1.6'],
    ['M8', '8.4', '16', '1.6'],
    ['M10', '10.5', '20', '2.0'],
    ['M12', '13', '24', '2.5'],
    ['M16', '17', '30', '3.0'],
    ['M20', '21', '37', '3.0'],
    ['M24', '25', '44', '4.0'],
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _table(context, [
          '螺纹规格', '内径 d₁\n(mm)', '外径 d₂\n(mm)', '厚度 h\n(mm)',
        ], _data),
        const SizedBox(height: 8),
        Text(
          '平垫圈 A 级 GB/T 97.1【待核对】。'
          '作用：分散预紧压力、保护表面、填补过大孔。\n'
          '弹簧垫圈 GB/T 93 靠弹性防松（高频振动场合不可靠，'
          '重要连接推荐达克罗+尼龙垫圈或螺纹胶）。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
        ),
      ],
    );
  }
}

// ==================== 公共表格 ====================
Widget _table(BuildContext context, List<String> headers, List<List<String>> rows) {
  final scheme = Theme.of(context).colorScheme;
  return Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerHighest),
        columnSpacing: 14,
        columns: [
          for (final h in headers)
            DataColumn(
              label: Text(h,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5)),
              numeric: true,
            ),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              for (var i = 0; i < r.length; i++)
                DataCell(Text(
                  r[i],
                  style: i == 0
                      ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)
                      : TextStyle(fontSize: 11, color: scheme.onSurface),
                )),
            ]),
        ],
      ),
    ),
  );
}
