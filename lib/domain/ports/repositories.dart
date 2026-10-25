import '../models/knowledge_models.dart';
import '../models/tolerance_models.dart';

/// 数据访问接口：domain 层只依赖抽象，实现在 data 层（Drift）。
abstract class ToleranceRepository {
  /// 在 ISO 主分段中查找基本尺寸所在段（区间为 (下限, 上限]）。
  Future<SizeStepInfo?> findStep(double nominalSize);

  /// 标准公差值（μm）。
  Future<int?> itValueUm({
    required String standardCode,
    required String stepId,
    required String gradeId,
  });

  /// 基本偏差值。
  Future<DeviationValue?> deviationOverride({
    required String standardCode,
    required String devId,
    required double nominalSize,
  });

  Future<DeviationValue?> deviationValue({
    required String standardCode,
    required String stepId,
    required String devId,
  });
}

abstract class KnowledgeRepository {
  /// 按 relation_type + subject_ref 查询关系记录（取优先级最高的一条）。
  Future<RelationRecord?> relationBySubject({
    required String type,
    required String subject,
  });

  /// 按类型取全部启用关系（每日知识点推荐池用）。
  Future<List<RelationRecord>> relationsByType(String type);

  /// 两个标准之间的 STANDARD_EQUIVALENCE 关系（双向匹配）。
  Future<RelationRecord?> standardEquivalence(String standardA, String standardB);

  Future<CardRecord?> cardByKey(String? cardKey);
}