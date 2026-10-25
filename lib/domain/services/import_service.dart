import 'dart:convert';

/// 自定义知识导入解析器：支持 JSON / CSV / Markdown 三种格式。
///
/// JSON:  [{"title":"...","text":"...","category":"..."}]（text/body/content 均可）
/// CSV:   首行为表头 title,text,category；字段可用英文双引号包裹（含逗号）。
/// Markdown: `#` 或 `##` 标题行 = 标题，其后至下一个标题 = 正文。
class ImportedEntry {
  const ImportedEntry({required this.title, required this.body, this.category});

  final String title;
  final String body;
  final String? category;
}

class ImportService {
  ImportService._();

  static List<ImportedEntry> parse(String filename, String content) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.json')) return _parseJson(content);
    if (lower.endsWith('.csv')) return _parseCsv(content);
    if (lower.endsWith('.md') || lower.endsWith('.markdown') || lower.endsWith('.txt')) {
      return _parseMarkdown(content);
    }
    // 无扩展名时自动嗅探
    final t = content.trim();
    if (t.startsWith('[') || t.startsWith('{')) return _parseJson(content);
    if (t.contains(',') && t.contains('\n')) return _parseCsv(content);
    return _parseMarkdown(content);
  }

  static List<ImportedEntry> _parseJson(String content) {
    final decoded = jsonDecode(content);
    final list = decoded is List ? decoded : (decoded['items'] as List? ?? const []);
    final out = <ImportedEntry>[];
    for (final e in list) {
      if (e is! Map) continue;
      final title = (e['title'] ?? e['标题'] ?? '') as String;
      final body = (e['text'] ?? e['body'] ?? e['content'] ?? e['正文'] ?? '') as String;
      if (title.isEmpty || body.isEmpty) continue;
      out.add(ImportedEntry(
        title: title,
        body: body,
        category: (e['category'] ?? e['分类']) as String?,
      ));
    }
    return out;
  }

  static List<ImportedEntry> _parseCsv(String content) {
    final lines = _csvRows(content);
    if (lines.isEmpty) return const [];
    final header = lines.first.map((h) => h.trim().toLowerCase()).toList();
    final titleIdx = header.contains('title') ? header.indexOf('title') : 0;
    final textIdx = header.contains('text') ? header.indexOf('text') : 1;
    final catIdx = header.indexOf('category');
    final out = <ImportedEntry>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = lines[i];
      if (titleIdx >= cells.length || textIdx >= cells.length) continue;
      final title = cells[titleIdx].trim();
      final body = cells[textIdx].trim();
      if (title.isEmpty || body.isEmpty) continue;
      out.add(ImportedEntry(
        title: title,
        body: body,
        category: catIdx >= 0 && catIdx < cells.length ? cells[catIdx].trim() : null,
      ));
    }
    return out;
  }

  static List<ImportedEntry> _parseMarkdown(String content) {
    final out = <ImportedEntry>[];
    String? title;
    final body = StringBuffer();

    void flush() {
      final b = body.toString().trim();
      if (title != null && title.isNotEmpty && b.isNotEmpty) {
        out.add(ImportedEntry(title: title, body: b));
      }
      body.clear();
    }

    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final m = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(raw);
      if (m != null) {
        flush();
        title = m.group(1)!.trim();
      } else if (title != null) {
        body.writeln(raw);
      }
    }
    flush();
    return out;
  }

  /// 极简 CSV 解析：支持双引号包裹与 "" 转义。
  static List<List<String>> _csvRows(String content) {
    final rows = <List<String>>[];
    var cell = StringBuffer();
    var row = <String>[];
    var inQuotes = false;
    for (var i = 0; i < content.length; i++) {
      final ch = content[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
      } else if (ch == ',') {
        row.add(cell.toString());
        cell.clear();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < content.length && content[i + 1] == '\n') i++;
        row.add(cell.toString());
        cell.clear();
        if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
        row = <String>[];
      } else {
        cell.write(ch);
      }
    }
    row.add(cell.toString());
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    return rows;
  }
}
