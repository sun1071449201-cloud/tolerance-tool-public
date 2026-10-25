import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tolerance_tool/presentation/widgets/reader_markdown.dart';

void main() {
  group('阅读器 Markdown 扩展', () {
    test('单个波浪号表示范围时不会被解析成删除线', () {
      const raw = 'M6: 9~11 N·m；M8: 22~26；M10: 44~52';
      final reader = md.markdownToHtml(
        raw,
        extensionSet: readerMarkdownExtensions,
      );
      expect(reader, isNot(contains('<del>')));
      expect(reader, contains('9~11'));
    });
  });
}