import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/book_providers.dart';

/// 收藏按钮：点击切换收藏状态（⭐/☆），持久化到 favorites 表。
class FavoriteStarButton extends ConsumerStatefulWidget {
  const FavoriteStarButton({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.targetKey,
    this.targetAnchor,
  });

  final String kind;
  final String title;
  final String subtitle;
  final String targetKey;
  final String? targetAnchor;

  @override
  ConsumerState<FavoriteStarButton> createState() => _FavoriteStarButtonState();
}

class _FavoriteStarButtonState extends ConsumerState<FavoriteStarButton> {
  bool _favorited = false;

  @override
  void initState() {
    super.initState();
    // 只在初始化时读一次库，避免每次 rebuild 都查 SQLite。
    _load();
  }

  Future<void> _load() async {
    final v =
        await ref.read(userDataRepositoryProvider).isFavorited(widget.targetKey);
    if (mounted) {
      setState(() => _favorited = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: _favorited ? '取消收藏' : '收藏',
      icon: Icon(
        _favorited ? Icons.star : Icons.star_border,
        size: 20,
        color: _favorited
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () async {
        final repo = ref.read(userDataRepositoryProvider);
        if (_favorited) {
          // 找到并删除
          final all = await repo.allFavorites();
          for (final f in all) {
            if (f.targetKey == widget.targetKey) {
              await repo.deleteFavorite(f.id);
              break;
            }
          }
        } else {
          await repo.addFavorite(
            kind: widget.kind,
            title: widget.title,
            subtitle: widget.subtitle,
            targetKey: widget.targetKey,
            targetAnchor: widget.targetAnchor,
          );
        }
        setState(() => _favorited = !_favorited);
      },
    );
  }
}
