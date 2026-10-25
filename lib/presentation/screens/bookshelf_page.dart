import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../../core/theme/app_theme.dart';
import '../state/book_providers.dart';
import '../dialogs/import_knowledge_dialog.dart';
import '../dialogs/backup_restore_dialog.dart';
import '../dialogs/data_cleanup_dialog.dart';
import 'about_page.dart';
import 'book_toc_page.dart';
import 'bookmarks_manage_page.dart';
import 'global_search_page.dart';

/// Tab：知识书籍。书架 + 书签管理 + 自定义知识导入 + 主题切换。
class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  void _pickTheme(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeControllerProvider);
    final seedName = ref.watch(seedColorControllerProvider);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('外观设置',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            // 亮度模式
            for (final m in const [
              (ThemeMode.system, '跟随系统', Icons.brightness_auto),
              (ThemeMode.light, '浅色模式', Icons.light_mode),
              (ThemeMode.dark, '深色模式', Icons.dark_mode),
            ])
              ListTile(
                leading: Icon(m.$3),
                title: Text(m.$2),
                trailing:
                    current == m.$1 ? const Icon(Icons.check) : null,
                onTap: () {
                  ref.read(themeModeControllerProvider.notifier).choose(m.$1);
                  Navigator.pop(ctx);
                },
              ),
            const Divider(),
            // 色板
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('主题色', style: Theme.of(ctx).textTheme.labelLarge),
            ),
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  for (final entry in AppTheme.seedNames.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () {
                          ref.read(seedColorControllerProvider.notifier).choose(entry.key);
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppTheme.seedOf(entry.key),
                                shape: BoxShape.circle,
                                border: seedName == entry.key
                                    ? Border.all(
                                        color: Theme.of(ctx).colorScheme.primary,
                                        width: 3)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(entry.value,
                                style: Theme.of(ctx).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('知识书籍'),
        actions: [
          IconButton(
            tooltip: '全局搜索',
            icon: const Icon(Icons.travel_explore),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GlobalSearchPage())),
          ),
          IconButton(
            tooltip: '我的书签',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BookmarksManagePage())),
          ),
          IconButton(
            tooltip: '数据清理',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () => showDialog(
                context: context,
                builder: (_) => const DataCleanupDialog()),
          ),
          IconButton(
            tooltip: '备份与恢复',
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: () => showDialog(
                context: context,
                builder: (_) => const BackupRestoreDialog()),
          ),
          IconButton(
            tooltip: '导入自定义知识',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => showDialog(
                context: context,
                builder: (_) => const ImportKnowledgeDialog()),
          ),
          IconButton(
            tooltip: '主题（跟随系统/浅色/深色）',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () => _pickTheme(context, ref),
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('书籍加载失败：$e')),
        data: (books) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final book in books)
              _BookCover(book: book, chapterCount: book.chapters.length),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '全部内容已内置 · 完全离线可读',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutPage())),
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('关于与数据说明'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.book, required this.chapterCount});

  final Book book;
  final int chapterCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPrimary = book.accent == 'primary';
    final base = isPrimary ? scheme.primary : scheme.tertiary;
    final onColor = isPrimary ? scheme.onPrimary : scheme.onTertiaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BookTocPage(book: book),
          )),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base, base.withOpacity(0.55)],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '随身手册 · 离线阅读',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: onColor.withOpacity(0.85),
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 10),
                Text(
                  book.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: onColor, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  book.subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: onColor.withOpacity(0.9)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.auto_stories, size: 16, color: onColor),
                    const SizedBox(width: 6),
                    Text('共 $chapterCount 章',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: onColor)),
                    const Spacer(),
                    Text('开始阅读 →',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: onColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
