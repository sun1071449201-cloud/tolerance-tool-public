import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首屏大卡片导航：最常用功能的快捷入口。
///
/// 布局说明：四张卡片用固定主轴高度（mainAxisExtent）+ FittedBox 收口，
/// 不再依赖 childAspectRatio 推算高度；小屏/大字号下标题和副标题只会缩放，
/// 不会把 BOTTOM OVERFLOWED 甩到用户脸上。
class HomeQuickCards extends ConsumerWidget {
  const HomeQuickCards({
    super.key,
    required this.onOpenSolver,
    required this.onOpenSearch,
    required this.onOpenTools,
    required this.onOpenGdnt,
  });

  final VoidCallback onOpenSolver;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenTools;
  final VoidCallback onOpenGdnt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    Widget bigCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required Gradient gradient,
      required Color fg,
      required VoidCallback onTap,
    }) {
      return Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(gradient: gradient),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: fg),
                const Spacer(),
                SizedBox(
                  height: 20,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: fg, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 16,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: fg.withOpacity(0.9)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cards = <Widget>[
      bigCard(
        title: '公差反选求解',
        subtitle: '输入间隙/过盈 → 推荐配合',
        icon: Icons.auto_fix_high,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
        ),
        fg: scheme.onPrimary,
        onTap: onOpenSolver,
      ),
      bigCard(
        title: '全局搜索',
        subtitle: '公差 · 单词 · 书籍 · 速查',
        icon: Icons.travel_explore,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.tertiary, scheme.tertiary.withOpacity(0.7)],
        ),
        fg: scheme.onTertiaryContainer,
        onTap: onOpenSearch,
      ),
      bigCard(
        title: 'GD&T 公差带图解',
        subtitle: '14 项图形化面板',
        icon: Icons.category,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.secondary, scheme.secondary.withOpacity(0.7)],
        ),
        fg: scheme.onSecondary,
        onTap: onOpenGdnt,
      ),
      bigCard(
        title: '机械小工具',
        subtitle: '重量·扭矩·热膨胀·L10…',
        icon: Icons.construction,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
        ),
        fg: scheme.onPrimaryContainer,
        onTap: onOpenTools,
      ),
    ];

    return SizedBox(
      // 2 行 × 100 + 中间 8 间距。固定高度，避免 childAspectRatio 随屏宽变矮。
      height: 208,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        itemCount: cards.length,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 100,
        ),
        itemBuilder: (_, index) => cards[index],
      ),
    );
  }
}
