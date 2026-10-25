import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/data/database/app_database.dart';

void main() {
  test('schema v14 包含新增表和字段', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('vocab_progress'));
    expect(names, contains('daily_history'));
    expect(names, contains('fundamental_deviation_overrides'));
    expect(names, contains('quick_ref_progress'));
    expect(names, contains('chapter_learning_progress'));

    Future<Set<String>> columns(String table) async {
      final rows = await db.customSelect('PRAGMA table_info($table)').get();
      return rows.map((r) => r.read<String>('name')).toSet();
    }

    expect(await columns('bookmarks'), contains('anchor'));
    expect(await columns('quick_ref_items'), contains('source_ref'));
    expect(await columns('vocab_progress'), containsAll(
      ['status', 'interval_days', 'due_at', 'lapses'],
    ));
    await db.close();
  });
}