import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/book_providers.dart';

/// 数据清理对话框：清除查询历史 / 全部用户缓存。
class DataCleanupDialog extends ConsumerStatefulWidget {
  const DataCleanupDialog({super.key});

  @override
  ConsumerState<DataCleanupDialog> createState() => _DataCleanupDialogState();
}

class _DataCleanupDialogState extends ConsumerState<DataCleanupDialog> {
  String _result = '';

  Future<void> _clear(String what) async {
    final label = what == 'history' ? '查询历史' : '用户缓存（书签/进度/已读/收藏/历史）';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('清除 $label？'),
        content: what == 'history'
            ? const Text('仅清除查询历史记录，其余数据不受影响。')
            : const Text('将清除全部书签、阅读进度、已读标记、收藏与历史（不可恢复）。'
                '自定义导入的知识也会保留（属于内容而非缓存）。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认清除')),
        ],
      ),
    );
    if (confirmed != true) return;
    final n = await ref
        .read(userDataRepositoryProvider)
        .clearUserData(what: what);
    ref.invalidate(queryHistoryProvider);
    ref.invalidate(allFavoritesProvider);
    ref.invalidate(readMarksProvider);
    setState(() => _result = '已清除 $n 条记录。');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('数据清理'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('清理本地数据以释放空间或重置使用痕迹。'),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('清除查询历史'),
              subtitle: const Text('最近 50 条查询记录'),
              onTap: () => _clear('history'),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('清除全部用户缓存'),
              subtitle: const Text('书签 / 进度 / 已读 / 收藏 / 历史'),
              onTap: () => _clear('cache'),
            ),
            if (_result.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('✅ $_result',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('完成')),
      ],
    );
  }
}
