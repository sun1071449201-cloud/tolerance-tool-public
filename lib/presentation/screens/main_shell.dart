import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../app_shortcuts.dart';
import '../state/book_providers.dart';
import 'bookshelf_page.dart';
import 'chapter_reading_page.dart';
import 'dimension_fit_query_page.dart';
import 'quick_ref_detail_page.dart';
import 'quick_ref_page.dart';
import 'vocab_page.dart';

/// 主壳：底部导航四 Tab（公差查询 / 机械英语 / 工程速查 / 知识书籍）。
/// 支持桌面快捷菜单（quick_actions）与跨模块跳转。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(fontScaleControllerProvider.notifier).load();
      ref.read(themeModeControllerProvider.notifier).load();
      ref.read(seedColorControllerProvider.notifier).load();
    });
    // Android 桌面快捷菜单
    AppShortcuts.init((type) {
      final target = AppShortcuts.targets[type];
      if (target == null || !mounted) return;
      if (target.startsWith('tab:')) {
        setState(() => _index = int.parse(target.substring(4)));
      } else if (target.startsWith('quickref:')) {
        setState(() => _index = 2);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              QuickRefDetailPage(refId: target.substring('quickref:'.length)),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 全局搜索 → 查询页预填并执行
    ref.listen<String?>(pendingQueryProvider, (prev, next) {
      if (next == null || !mounted) return;
      setState(() => _index = 0);
      ref.read(pendingQueryProvider.notifier).state = null;
    });

    ref.listen<ChapterJump?>(chapterOpenRequestProvider, (prev, next) {
      if (next == null || !mounted) return;
      // 先清请求，防止失败路径下重复触发。
      ref.read(chapterOpenRequestProvider.notifier).state = null;

      // 不在 build 阶段直接 push 路由：统一收到下一帧，避免路由/Overlay
      // 尚未就绪时触发空断言。这里也不使用 `!`，所有值先落到局部变量再判空。
      final quickRefId = next.quickRefId?.trim() ?? '';
      final chapterKey = next.chapterKey?.trim() ?? '';
      final anchor = next.anchor?.trim();
      final hasQuickRef = quickRefId.isNotEmpty;
      final hasChapter = chapterKey.isNotEmpty;

      if (!hasQuickRef && !hasChapter) {
        // 章节与速查均未关联：友好提示，绝不崩溃。
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('这条知识点还没有关联详细解析，换个关键词搜搜看'),
        ));
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (hasQuickRef && !hasChapter) {
          // 今日知识点 → 速查条目详情。
          setState(() => _index = 2);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => QuickRefDetailPage(refId: quickRefId),
          ));
        } else if (hasChapter) {
          // 知识卡 → 书籍章节（含锚点）。
          setState(() => _index = 3);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChapterReadingPage(
              chapterKey: chapterKey,
              anchor: anchor,
            ),
          ));
        }
      });
    });

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DimensionFitQueryPage(),
          VocabPage(),
          QuickRefPage(),
          BookshelfPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: '公差查询',
          ),
          NavigationDestination(
            icon: Icon(Icons.translate_outlined),
            selectedIcon: Icon(Icons.translate),
            label: '机械英语',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: '工程速查',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '知识书籍',
          ),
        ],
      ),
    );
  }
}