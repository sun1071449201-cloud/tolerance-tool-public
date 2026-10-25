import 'package:flutter_test/flutter_test.dart';
import 'package:tolerance_tool/domain/models/book_models.dart';

void main() {
  group('章节锚点解析（跳转精准定位）', () {
    const content = ChapterContent(
      chapterKey: 'demo_book.ch01',
      bookId: 'demo_book',
      chapterTitle: '第一章 演示',
      bookTitle: '演示书',
      bodyMarkdown: '',
      segments: [
        ChapterSegment(heading: null, bodyMd: '章首导语'),
        ChapterSegment(heading: '1.1 总则', bodyMd: '正文'),
        ChapterSegment(heading: '1.2 配合制', bodyMd: '正文'),
        ChapterSegment(heading: '1.2.1 基孔制', bodyMd: '正文'),
        ChapterSegment(heading: '1.10 附录', bodyMd: '正文'),
      ],
    );

    test('节号按完整编号匹配，不会把 1.2 误跳到 1.2.1', () {
      expect(content.resolveAnchor('1.2'), 2);
      expect(content.resolveAnchor(' 1.2 '), 2);
      expect(content.resolveAnchor('1.2.1'), 3);
    });

    test('不会把 1.1 误匹配到 1.10', () {
      expect(content.resolveAnchor('1.1'), 1);
      expect(content.resolveAnchor('1.10'), 4);
    });

    test('空锚点、不存在的节号、带尾部点号都返回 null', () {
      expect(content.resolveAnchor(null), isNull);
      expect(content.resolveAnchor(''), isNull);
      expect(content.resolveAnchor('9.9'), isNull);
      expect(content.resolveAnchor('1.2.'), isNull);
    });

    test('旧数据里的文字锚点仍可按前缀匹配', () {
      expect(content.resolveAnchor('1.1 总则'), 1);
      expect(content.resolveAnchor('1.2 配合'), 2);
    });
  });

  group('ChapterJump 空值保护', () {
    test('只有非空 quickRefId 时才走速查详情', () {
      expect(const ChapterJump(quickRefId: 'qr_a').isQuickRef, isTrue);
      expect(const ChapterJump(quickRefId: '  ').isQuickRef, isFalse);
      expect(const ChapterJump(quickRefId: null).isQuickRef, isFalse);
    });

    test('同时带章节和速查时优先章节，不误判为速查', () {
      expect(
        const ChapterJump(
          chapterKey: 'qc_book.ch01',
          quickRefId: 'qr_a',
        ).isQuickRef,
        isFalse,
      );
    });

    test('章节键只有空白时视为没有章节', () {
      expect(const ChapterJump(chapterKey: '  ').isQuickRef, isFalse);
    });
  });
}