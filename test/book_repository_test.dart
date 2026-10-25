import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/data/repositories/book_repositories.dart';

void main() {
  late AssetBookRepository repo;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    repo = AssetBookRepository();
  });

  group('书籍数据（manifest + Markdown）', () {
    test('书架包含五本书，章节键唯一', () async {
      final books = await repo.loadBooks();
      expect(books.length, 5);
      expect(books.any((b) => b.bookId == 'pitfall_book'), isTrue);
      expect(books.any((b) => b.bookId == 'auto_book'), isTrue);
      final keys = <String>{};
      for (final b in books) {
        for (final c in b.chapters) {
          expect(keys.contains(c.key), isFalse, reason: '重复章节键 ${c.key}');
          keys.add(c.key);
        }
      }
      expect(keys.contains('qc_book.ch01'), isTrue);
      expect(keys.contains('growth_book.ch02'), isTrue);
      expect(keys.contains('growth_book.appendix'), isTrue);
    });

    test('QC 手册第一章可加载且含判定红线小节', () async {
      final c = await repo.loadChapter('qc_book.ch01');
      expect(c.chapterTitle, contains('GD&T'));
      expect(c.bodyMarkdown, isNotEmpty);
      expect(c.sections, isNotEmpty);
      expect(c.nextKey, 'qc_book.ch02');
    });

    test('成长手册第二章含公差与配合内容（知识卡跳转目标）', () async {
      final c = await repo.loadChapter('growth_book.ch02');
      expect(c.prevKey, 'growth_book.ch01');
    });

    test('两本书首章无上一章、末章无下一章', () async {
      final first = await repo.loadChapter('qc_book.ch00');
      final last = await repo.loadChapter('growth_book.appendix');
      expect(first.prevKey, isNull);
      expect(last.nextKey, isNull);
    });

    test('不存在的章节键抛出异常（不静默）', () async {
      expect(() => repo.loadChapter('qc_book.nope'), throwsA(isA<StateError>()));
    });

    test('第 4 本书摘要可加载', () async {
      final books = await repo.loadBooks();
      expect(books.any((b) => b.bookId == 'new_book'), isTrue);
      final c = await repo.loadChapter('new_book.ch01');
      expect(c.sections.length, greaterThanOrEqualTo(4));
      expect(c.segments.length, greaterThanOrEqualTo(c.sections.length));
    });

    test('摘要分段正常（qc ch01 结论段可加载）', () async {
      final c = await repo.loadChapter('qc_book.ch01');
      expect(c.sections, isNotEmpty);
      expect(c.bodyMarkdown, contains('结论'));
    });

    test('摘要搜索可命中章节', () async {
      final hits = await repo.searchContent('检查清单');
      expect(hits, isNotEmpty);
      expect(hits.any((h) => h.chapterKey == 'qc_book.ch01'), isTrue);
    });

    test('避坑指南可加载：24 章、Mermaid 块保留、术语锚点已转纯文本', () async {
      final c = await repo.loadChapter('pitfall_book.ch01');
      expect(c.sections.length, greaterThanOrEqualTo(4));
      expect(c.bodyMarkdown, contains('```mermaid'));
      expect(c.bodyMarkdown.contains('<a id='), isFalse);
      expect(c.nextKey, 'pitfall_book.ch02');
      final last = await repo.loadChapter('pitfall_book.ch23');
      expect(last.nextKey, isNull);
      final ch05 = await repo.loadChapter('pitfall_book.ch05');
      expect(ch05.bodyMarkdown, contains('sketch:dimgap'));
    });
  });
}