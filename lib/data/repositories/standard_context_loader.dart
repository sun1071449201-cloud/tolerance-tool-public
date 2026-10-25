import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../../domain/models/standard_context.dart';

/// 从 app_settings + standard_family_map 构建当前标准上下文。
/// 里程碑 6 接入全局切换 UI 后，此处将改为响应切换事件。
class StandardContextLoader {
  StandardContextLoader(this._db);

  final AppDatabase _db;

  Future<StandardContext> load() async {
    final setting = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals('current_family')))
        .getSingleOrNull();
    final family = setting?.value ?? 'ISO';

    final row = await (_db.select(_db.standardFamilyMap)
          ..where((t) => t.family.equals(family) & t.domain.equals('dimension')))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('standard_family_map 缺少 $family/dimension 配置');
    }
    final chain = (jsonDecode(row.fallbackChain) as List).cast<String>();
    return StandardContext(
      family: family,
      primaryStandard: row.primaryStandard,
      fallbackChain: chain,
    );
  }
}
