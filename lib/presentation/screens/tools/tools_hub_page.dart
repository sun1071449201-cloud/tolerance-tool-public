import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/book_providers.dart';
import '../gdnt_panel_page.dart';
import 'auto_sizing_page.dart';
import 'bearing_page.dart';
import 'beam_calc_page.dart';
import 'bolt_torque_page.dart';
import 'it_browser_page.dart';
import 'linear_motion_page.dart';
import 'material_compare_page.dart';
import 'mech_calc_page.dart';
import 'metrology_page.dart';
import 'motor_sizing_page.dart';
import 'parts_library_page.dart';
import 'process_data_page.dart';
import 'roughness_page.dart';
import 'thermal_page.dart';
import 'tolerance_chain_page.dart';
import 'unit_convert_page.dart';
import 'weight_calc_page.dart';

/// 工具条目。
class _Tool {
  const _Tool(this.name, this.desc, this.icon, this.builder);
  final String name;
  final String desc;
  final IconData icon;
  final WidgetBuilder builder;
}

/// 机械小工具集散页：分类（计算/选型/查表）+ 长按置顶（持久化）。
class ToolsHubPage extends ConsumerStatefulWidget {
  const ToolsHubPage({super.key});

  @override
  ConsumerState<ToolsHubPage> createState() => _ToolsHubPageState();
}

class _ToolsHubPageState extends ConsumerState<ToolsHubPage> {
  static const _pinKey = 'pinned_tools';

  static const _calcTools = <_Tool>[
    _Tool('重量计算器', '材料密度 × 形状尺寸', Icons.scale, _mkWeight),
    _Tool('单位换算', 'MPa·英寸·扭矩', Icons.swap_horiz, _mkUnit),
    _Tool('螺栓扭矩', '规格 × 等级 × 摩擦', Icons.build, _mkBolt),
    _Tool('尺寸链堆叠', '极值法 / RSS', Icons.account_tree, _mkChain),
    _Tool('热膨胀', 'α × L × ΔT 变形量', Icons.thermostat, _mkThermal),
    _Tool('Ra/Rz 转换', '粗糙度对照表', Icons.waves, _mkRough),
    _Tool('轴承 L10', '寿命估算 (C/P)^ε', Icons.settings, _mkBearing),
    _Tool('梁挠度/截面', 'I·W·δ 一体化', Icons.architecture, _mkBeam),
    _Tool('传动计算', '功率·齿轮·弹簧·压配·同步带', Icons.settings_suggest,
        _mkMech),
    _Tool('电机选型', '伺服扭矩/惯量比/RMS', Icons.bolt, _mkMotor),
  ];

  static const _sizingTools = <_Tool>[
    _Tool('非标选型助手', '丝杠·导轨·气缸一站式', Icons.precision_manufacturing,
        _mkAuto),
    _Tool('直线传动选型', '滚珠丝杠·直线导轨', Icons.linear_scale, _mkLinear),
    _Tool('材料对比', '15 种材料一屏对比', Icons.compare_arrows, _mkMat),
    _Tool('标准件库', '螺栓·轴承·键·销·卡簧·O圈', Icons.inventory_2, _mkParts),
  ];

  static const _refTools = <_Tool>[
    _Tool('IT 公差表', '全表色阶可视化', Icons.grid_on, _mkIt),
    _Tool('工艺数据', '硬度·摩擦·效率·扳手', Icons.construction, _mkProc),
    _Tool('GD&T 公差带', '14 种图解', Icons.category, _mkGdnt),
  ];

  static const _metrologyTools = <_Tool>[
    _Tool('计量检测计算', 'CPK·正弦规·三针·锥度', Icons.straighten, _mkMetro),
  ];

  static Widget _mkWeight(_) => const WeightCalcPage();
  static Widget _mkUnit(_) => const UnitConvertPage();
  static Widget _mkBolt(_) => const BoltTorquePage();
  static Widget _mkChain(_) => const ToleranceChainPage();
  static Widget _mkThermal(_) => const ThermalPage();
  static Widget _mkRough(_) => const RoughnessPage();
  static Widget _mkBearing(_) => const BearingPage();
  static Widget _mkBeam(_) => const BeamCalcPage();
  static Widget _mkMech(_) => const MechCalcPage();
  static Widget _mkMotor(_) => const MotorSizingPage();
  static Widget _mkAuto(_) => const AutoSizingPage();
  static Widget _mkLinear(_) => const LinearMotionPage();
  static Widget _mkMat(_) => const MaterialComparePage();
  static Widget _mkParts(_) => const PartsLibraryPage();
  static Widget _mkIt(_) => const ITBrowserPage();
  static Widget _mkProc(_) => const ProcessDataPage();
  static Widget _mkGdnt(_) => const GdntPanelPage();
  static Widget _mkMetro(_) => const MetrologyPage();

  Set<String> _pinned = {};

  @override
  void initState() {
    super.initState();
    _loadPins();
  }

  Future<void> _loadPins() async {
    final v = await ref
        .read(settingsRepositoryProvider)
        .get(_pinKey);
    if (!mounted || v == null || v.isEmpty) return;
    try {
      final list = (jsonDecode(v) as List).cast<String>();
      setState(() => _pinned = list.toSet());
    } catch (_) {
      // 坏数据忽略，视为无置顶
    }
  }

  Future<void> _togglePin(String name) async {
    setState(() {
      if (_pinned.contains(name)) {
        _pinned.remove(name);
      } else {
        _pinned.add(name);
      }
    });
    await ref
        .read(settingsRepositoryProvider)
        .set(_pinKey, jsonEncode(_pinned.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final pinned = [
      for (final group in [_calcTools, _sizingTools, _refTools, _metrologyTools])
        for (final t in group)
          if (_pinned.contains(t.name)) t,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('机械小工具'),
        actions: [
          if (_pinned.isNotEmpty)
            IconButton(
              tooltip: '清空置顶',
              icon: const Icon(Icons.clear_all, size: 20),
              onPressed: () async {
                setState(() => _pinned = {});
                await ref
                    .read(settingsRepositoryProvider)
                    .set(_pinKey, '[]');
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_pinned.isNotEmpty) ...[
            _sectionHeader(context, '⭐ 常用（长按取消）'),
            _grid(context, pinned, isPinnedSection: true),
            const SizedBox(height: 8),
          ],
          _sectionHeader(context, '🧮 计算类'),
          _grid(context, _calcTools),
          const SizedBox(height: 8),
          _sectionHeader(context, '🎯 选型类'),
          _grid(context, _sizingTools),
          const SizedBox(height: 8),
          _sectionHeader(context, '📖 查表类'),
          _grid(context, _refTools),
          const SizedBox(height: 8),
          _sectionHeader(context, '📏 检测类'),
          _grid(context, _metrologyTools),
          const SizedBox(height: 8),
          Text('长按任意工具可置顶/取消置顶，置顶保存在本机。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _grid(BuildContext context, List<_Tool> tools,
      {bool isPinnedSection = false}) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        for (final t in tools)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: t.builder)),
              onLongPress: () => _togglePin(t.name),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(t.icon,
                        size: 26,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(t.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold)),
                            ),
                            if (isPinnedSection)
                              const Icon(Icons.push_pin,
                                  size: 11,
                                  color: Colors.orange),
                          ]),
                          const SizedBox(height: 2),
                          Text(t.desc,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
