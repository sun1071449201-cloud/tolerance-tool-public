import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/book_models.dart';
import '../../domain/models/knowledge_models.dart';
import '../state/book_providers.dart';

/// 知识提示卡：渲染 KnowledgeTip，显示追溯信息，并在关联了书籍章节时
/// 提供「去书籍中查看完整解析」跳转按钮。
class KnowledgeTipCard extends ConsumerWidget {
  const KnowledgeTipCard({super.key, required this.tip});

  final KnowledgeTip tip;

  /// 按“老师傅口吻”的语义给标题配 Emoji 锚点：⚠️ 禁忌/风险、💡 技巧、
  /// 📏 尺寸/公差、🔩 材料/紧固、📐 形位/基准。
  String _emojiFor(KnowledgeTip tip) {
    final t = '${tip.title}${tip.text}';
    if (t.contains('禁') || t.contains('不得') || t.contains('风险') ||
        t.contains('注意') || t.contains('别')) {
      return '⚠️';
    }
    if (t.contains('公差') || t.contains('偏差') || t.contains('尺寸') ||
        t.contains('μm') || t.contains('mm')) {
      return '📏';
    }
    if (t.contains('基准') || t.contains('平面度') || t.contains('位置度') ||
        t.contains('平行')) {
      return '📐';
    }
    if (t.contains('材料') || t.contains('钢') || t.contains('铝') ||
        t.contains('螺栓') || t.contains('螺')) {
      return '🔩';
    }
    return '💡';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final chapterKey = tip.chapterKey?.trim() ?? '';
    final anchor = tip.anchor?.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_emojiFor(tip), style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(tip.title, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(tip.text, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              '依据：${tip.trace}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (chapterKey.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(chapterOpenRequestProvider.notifier).state =
                        ChapterJump(
                      chapterKey: chapterKey,
                      anchor: anchor,
                    );
                  },
                  icon: const Icon(Icons.menu_book, size: 16),
                  label: Text(anchor == null || anchor.isEmpty
                      ? '去书籍中查看完整解析'
                      : '去书籍中定位到 $anchor 节'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}