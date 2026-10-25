import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tolerance_tool/data/database/app_database.dart';

void main() {
  test('v6 → v14 升级：补齐书签/速查字段并创建新表', () async {
    final dir = await Directory.systemTemp.createTemp('tol_migration');
    final file = File('${dir.path}/old.sqlite');
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        chapter_key TEXT NOT NULL,
        chapter_title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE quick_ref_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_id TEXT NOT NULL,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        content_md TEXT NOT NULL,
        keywords TEXT NOT NULL,
        tip TEXT NOT NULL
      )
    ''');
    raw.execute('PRAGMA user_version = 6');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    await db.customSelect('SELECT 1').get();

    Future<Set<String>> columns(String table) async {
      final rows = await db.customSelect('PRAGMA table_info($table)').get();
      return rows.map((r) => r.read<String>('name')).toSet();
    }

    expect(await columns('bookmarks'), contains('anchor'));
    expect(await columns('quick_ref_items'), contains('source_ref'));
    expect(await columns('vocab_progress'), containsAll(
      ['status', 'interval_days', 'due_at', 'lapses'],
    ));
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('daily_history'));
    expect(names, contains('fundamental_deviation_overrides'));
    expect(names, contains('quick_ref_progress'));
    expect(names, contains('chapter_learning_progress'));

    await db.close();
    await dir.delete(recursive: true);
  });
}