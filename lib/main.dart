import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/database/seed/seed_files.dart';
import 'data/database/seed/seed_importer.dart';
import 'data/repositories/standard_context_loader.dart';
import 'domain/models/standard_context.dart';
import 'presentation/state/providers.dart';

/// 启动流程：立即渲染品牌启动页（消除白屏），种子导入与标准上下文后台完成，
/// 就绪后无缝切入主界面。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 最后一道兜底：release 包里任何页面渲染异常都显示可读提示，
  // 不再把红屏/堆栈直接甩给用户；debug 保留红屏，方便定位。
  if (kReleaseMode) {
    ErrorWidget.builder = (details) {
      debugPrint('页面渲染异常：${details.exception}');
      return const Material(
        color: Color(0xFFF7F7F7),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.build_circle_outlined, size: 40),
                SizedBox(height: 12),
                Text('这个页面出了点问题',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 6),
                Text('返回上一页再试，或到全局搜索里找相关内容。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    };
  }

  final db = AppDatabase();
  final ready = ValueNotifier<StandardContext?>(null);

  Future<void> startup() async {
    final files = <String, String>{};
    await Future.wait([
      for (final name in kSeedFiles)
        rootBundle
            .loadString('assets/data/$name')
            .then((v) => files[name] = v),
    ]);
    await SeedImporter(db).seedIfNeeded(files);
    ready.value = await StandardContextLoader(db).load();
  }

  unawaited(startup());

  runApp(_BootstrapApp(db: db, ready: ready));
}

class _BootstrapApp extends StatelessWidget {
  const _BootstrapApp({required this.db, required this.ready});

  final AppDatabase db;
  final ValueNotifier<StandardContext?> ready;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StandardContext?>(
      valueListenable: ready,
      builder: (context, ctx, _) {
        if (ctx == null) {
          // 启动页：数据库就绪前的品牌加载态。
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.straighten, size: 56),
                    SizedBox(height: 16),
                    Text('机械精度与几何公差',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 24),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            standardContextProvider.overrideWithValue(ctx),
          ],
          child: const ToleranceApp(),
        );
      },
    );
  }
}