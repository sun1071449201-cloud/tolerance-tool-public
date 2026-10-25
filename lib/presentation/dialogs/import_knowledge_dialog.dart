import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../domain/services/daily_service.dart';
import '../../domain/services/import_service.dart';
import '../state/book_providers.dart';

/// 自定义知识导入对话框：选择本地文件（JSON/CSV/Markdown）或粘贴文本。
/// 解析成功后写入 design_tips（isCustom=true）并自动进入每日推荐池。
class ImportKnowledgeDialog extends ConsumerStatefulWidget {
  const ImportKnowledgeDialog({super.key});

  @override
  ConsumerState<ImportKnowledgeDialog> createState() =>
      _ImportKnowledgeDialogState();
}

class _ImportKnowledgeDialogState extends ConsumerState<ImportKnowledgeDialog> {
  final _pasteController = TextEditingController();
  String _result = '';
  bool _ok = false;

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(
      label: '知识文件 (JSON/CSV/MD)',
      extensions: ['json', 'csv', 'md', 'markdown', 'txt'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final content = await file.readAsString();
    _apply(file.name, content);
  }

  void _apply(String name, String content) {
    try {
      final entries = ImportService.parse(name, content);
      if (entries.isEmpty) {
        setState(() {
          _ok = false;
          _result = '未解析到任何条目，请检查格式（模板见 docs/自定义导入模板.md）';
        });
        return;
      }
      final repo = ref.read(userDataRepositoryProvider);
      final importDate = DateTime.now();
      repo
          .addCustomTips([
        for (final e in entries)
          DesignTipsCompanion.insert(
            title: e.title,
            body: e.body,
            category: e.category ?? '我的笔记',
          ),
      ])
          .then((n) {
        ref.invalidate(dailyTipsProvider(DailyService.dayKeyOf(importDate)));
        ref.invalidate(readMarksProvider); // 刷新其他可能依赖的界面
      });
      setState(() {
        _ok = true;
        _result = '解析成功：${entries.length} 条已写入数据库，'
            '全部加入“今日知识点”推荐池（来源标签：我的笔记）。';
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _result = '导入失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入自定义知识'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('支持 JSON / CSV / Markdown 三种格式'
                '（格式模板见 docs/自定义导入模板.md）。'
                '导入的知识自动加入“今日知识点”推荐池，'
                '卡片上会显示“我的笔记”来源标签。'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('选择本地文件'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pasteController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '或直接粘贴 JSON / CSV / Markdown 文本',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _apply('粘贴内容.md', _pasteController.text),
              child: const Text('解析粘贴内容'),
            ),
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _ok ? '✅ $_result' : '⚠ $_result',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    );
  }
}
