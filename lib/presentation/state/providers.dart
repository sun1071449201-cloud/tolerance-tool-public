import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/exceptions.dart';
import '../../core/utils/format.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/user_data_repositories.dart';
import '../../domain/models/knowledge_models.dart';
import '../../domain/models/standard_context.dart';
import '../../domain/models/tolerance_models.dart';
import '../../domain/parsing/designation_parser.dart';
import '../../domain/ports/repositories.dart';
import '../../domain/services/knowledge_service.dart';
import '../../domain/services/tolerance_query_service.dart';

// 历史查询记录（本文件递归引用：写入方在下方 provider，读取方供 UI）。
import 'book_providers.dart' show queryHistoryProvider;

/// 在 main() 中 override（数据库与标准上下文需异步初始化）。
final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError('override in main()'));

/// 用户学习数据（书签/进度/已读/收藏/历史）——定义于此供各模块共用。
final userDataRepositoryProvider = Provider<DriftReadingUserDataRepository>(
    (ref) => DriftReadingUserDataRepository(ref.watch(databaseProvider)));

final standardContextProvider = Provider<StandardContext>(
    (ref) => throw UnimplementedError('override in main()'));

final toleranceRepositoryProvider = Provider<ToleranceRepository>(
    (ref) => DriftToleranceRepository(ref.watch(databaseProvider)));

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>(
    (ref) => DriftKnowledgeRepository(ref.watch(databaseProvider)));

final toleranceQueryServiceProvider = Provider<ToleranceQueryService>(
    (ref) => ToleranceQueryService(ref.watch(toleranceRepositoryProvider),
        ref.watch(knowledgeRepositoryProvider)));

final knowledgeServiceProvider = Provider<KnowledgeService>(
    (ref) => KnowledgeService(ref.watch(knowledgeRepositoryProvider)));

class QueryState {
  const QueryState({this.loading = false, this.result, this.tips = const [], this.error});

  final bool loading;
  final FitQueryResult? result;
  final List<KnowledgeTip> tips;
  final String? error;
}

class QueryController extends StateNotifier<QueryState> {
  QueryController(this._queryService, this._knowledgeService, this._ctx,
      {Future<void> Function(String, String)? historyRecorder})
      : _history = historyRecorder,
        super(const QueryState());

  final ToleranceQueryService _queryService;
  final KnowledgeService _knowledgeService;
  final StandardContext _ctx;
  final Future<void> Function(String, String)? _history;

  Future<void> query(String raw) async {
    state = const QueryState(loading: true);
    try {
      final designation = DesignationParser.parse(raw);
      final result = await _queryService.query(designation, _ctx);
      final tips = await _knowledgeService.tipsFor(result, _ctx);
      state = QueryState(result: result, tips: tips);
      // 成功查询写入历史（摘要一行）。
      final summary = result.fitType == null
          ? '孔 ${result.hole.zone.code}：ES ${formatUmSigned(result.hole.upperUm)} / EI ${formatUmSigned(result.hole.lowerUm)}'
          : '${result.fitType!.label}：'
              '${result.fitTerms.map((t) => '${t.label} ${t.isInterference ? formatUmMagnitude(t.um) : formatUmSigned(t.um)}').join('，')}';
      await _history?.call(result.input.display, summary);
    } on ParseException catch (e) {
      state = QueryState(error: e.message);
    } on DataNotSeedException catch (e) {
      state = QueryState(error: e.message);
    } catch (e) {
      state = QueryState(error: '查询失败：$e');
    }
  }
}

final queryControllerProvider =
    StateNotifierProvider<QueryController, QueryState>((ref) => QueryController(
          ref.watch(toleranceQueryServiceProvider),
          ref.watch(knowledgeServiceProvider),
          ref.watch(standardContextProvider),
          historyRecorder: (q, s) async {
            await ref.read(userDataRepositoryProvider).addHistory(q, s);
            // 写入后刷新历史条（否则查询后“最近查询”不更新）。
            ref.invalidate(queryHistoryProvider);
          },
        ));
