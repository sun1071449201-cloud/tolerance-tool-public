import 'package:flutter/material.dart';

/// 关于页：版本、离线数据说明、使用边界和换机提醒。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget section(String title, List<Widget> children) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
    }

    Widget line(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.5)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('关于与数据说明')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            color: scheme.primaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.straighten, size: 38),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('机械精度与几何公差',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('离线查询 · 学习 · 速查',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          section('版本', [
            line('0.2.0+27（v31）'),
            line('Flutter 3.24 · 完全离线，不联网、不上传数据。'),
          ]),
          section('数据说明', [
            line('内置 5 本书、63 章；50 条工程速查；586 条机械英语词条。'),
            line('IT 公差 234 行、ISO 2768 未注公差 48 行、基本偏差 234 行。'),
            line('标准数值按 ISO / GB 通用表整理；经验值在正文中单独标注。'),
            line('本 App 用于日常查询和学习，正式判定以标准原文、客户规范和图纸为准。'),
          ]),
          section('使用边界', [
            line('不替代计量检定、第三方检测和设计评审。'),
            line('螺纹、镀层、热处理等强工艺相关数据，以实际工艺文件和限度样件为准。'),
          ]),
          section('换机与备份', [
            line('换手机或卸载前，先到“知识书籍 → 备份与恢复”导出完整 JSON。'),
            line('备份包含书签、阅读进度、英语背诵进度、收藏和自定义知识。'),
          ]),
          const SizedBox(height: 8),
          Center(
            child: Text('个人自用工具 · 不对外发布',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
