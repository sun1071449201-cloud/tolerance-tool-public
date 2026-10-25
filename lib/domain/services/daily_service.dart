import 'dart:math';

import '../models/knowledge_models.dart';
import '../ports/repositories.dart';
import '../ports/learning_repository.dart';
import '../ports/user_data_repository.dart';

/// 每日知识点：推荐池 = daily_facts ∪ EXPLANATION_CARD ∪ 速查经验卡 ∪ 设计常识。
/// 同一天内多次打开结果不变（按日期确定性抽取），跨天自动刷新。
class DailyService {
  DailyService(
      this._factsRepo, this._knowledgeRepo, this._quickRefRepo, this._userDataRepo);

  final DailyFactsRepository _factsRepo;
  final KnowledgeRepository _knowledgeRepo;
  final QuickRefRepository _quickRefRepo;
  final ReadingUserDataRepository _userDataRepo;

  static const _count = 3;

  /// 本地日期键（yyyy-MM-dd），作为抽取的随机种子。
  static String dayKeyOf(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<List<DailyTip>> todays(DateTime day) async {
    final allPool = await _buildPool();
    if (allPool.isEmpty) return const [];
    final recent = await _userDataRepo.recentDailyTitles(days: 30);
    var pool = allPool.where((t) => !recent.contains(t.title)).toList();
    // 池子不够 3 条时退回全量，避免某天只推 1 条。
    if (pool.length < _count) pool = allPool;

    final dayKey = dayKeyOf(day);
    final seeded = Random(dayKey.hashCode);
    final shuffled = [...pool]..shuffle(seeded);

    // 每天至少给一条“速查经验”和一条“系统知识”，避免随机抽到三条
    // 同类型，表面处理/工艺经验长期不露面。
    final picked = <DailyTip>[];
    void addFirstWhere(bool Function(DailyTip) test) {
      for (final tip in shuffled) {
        if (picked.length >= _count) return;
        if (picked.contains(tip)) continue;
        if (test(tip)) {
          picked.add(tip);
          return;
        }
      }
    }

    addFirstWhere((t) =>
        t.sourceLabel == '速查经验' ||
        (t.quickRefId != null && t.quickRefId!.isNotEmpty));
    addFirstWhere((t) => t.sourceLabel == '系统知识');
    for (final tip in shuffled) {
      if (picked.length >= _count) break;
      if (!picked.contains(tip)) picked.add(tip);
    }

    // 排序保证展示稳定（同一天内顺序也不随打开次数变化）。
    picked.sort((a, b) => a.title.compareTo(b.title));
    await _userDataRepo.recordDailyTitles(
      dayKey,
      [for (final t in picked) t.title],
    );
    return picked;
  }

  Future<List<DailyTip>> _buildPool() async {
    final tips = <DailyTip>[];

    for (final f in await _factsRepo.all()) {
      tips.add(DailyTip(
        title: f.title,
        text: f.body,
        chapterKey: f.chapterKey,
        anchor: f.anchor,
        sourceLabel: '系统知识',
        trace: f.source ?? '每日知识池',
      ));
    }

    for (final r in await _knowledgeRepo.relationsByType('EXPLANATION_CARD')) {
      tips.add(DailyTip(
        title: _shortSubject(r.subject),
        text: r.statement,
        chapterKey: _field(r.payload, 'chapter') ?? '',
        anchor: _field(r.payload, 'anchor'),
        sourceLabel: '系统知识',
        trace: 'knowledge_relations #${r.id}',
      ));
    }

    // 速查条目的经验卡片进入推荐池（点击打开速查详情）。
    for (final q in await _quickRefRepo.all()) {
      tips.add(DailyTip(
        title: q.title,
        text: q.tip,
        chapterKey: '',
        quickRefId: q.refId,
        sourceLabel: '速查经验',
        trace: 'quick_ref_items:${q.refId}',
      ));
    }

    // 设计常识与禁忌（含用户自定义导入的条目，isCustom 决定来源标签）。
    for (final d in await _userDataRepo.allDesignTips()) {
      tips.add(DailyTip(
        title: d.title,
        text: d.body,
        chapterKey: d.chapterKey ?? '',
        anchor: d.anchor,
        sourceLabel: d.isCustom ? '我的笔记' : '系统知识',
        trace: 'design_tips #${d.id}${d.isCustom ? '（自定义导入）' : ''}',
      ));
    }

    // 仅保留可跳转或可展示的知识点（常识条目无跳转也可读）。
    return tips;
  }

  String _shortSubject(String subjectRef) {
    final tail = subjectRef.split(':').last;
    return tail.isEmpty ? subjectRef : tail;
  }

  String? _field(String payload, String field) {
    // 避免在 domain 层引入 dart:convert 之外的依赖；JSON 解析保持简单。
    final match = RegExp('"$field"\\s*:\\s*"([^"]+)"').firstMatch(payload);
    return match?.group(1);
  }
}