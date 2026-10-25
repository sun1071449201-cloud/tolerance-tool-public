import 'package:flutter/material.dart';

/// 轻量 Mermaid 子集渲染器：支持 graph TD / graph LR 的
/// `A[文本] --> B[文本]` 与 `A -->|标签| B` 语法，用 CustomPaint 绘制。
/// 覆盖尺寸链逻辑图、防错流程图等书籍用图需求（完全离线，无外部依赖）。
class MermaidLite extends StatelessWidget {
  const MermaidLite({super.key, required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final graph = _MermaidGraph.parse(source);
    if (graph.nodes.isEmpty) {
      return Text(source, style: const TextStyle(fontFamily: 'monospace', fontSize: 11));
    }
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: CustomPaint(
          painter: _MermaidPainter(graph: graph),
          child: AspectRatio(
            aspectRatio: graph.horizontal ? 1.6 : 0.9,
          ),
        ),
      ),
    );
  }
}

class _MNode {
  _MNode(this.id, this.label);
  final String id;
  String label;
  int level = 0;
  int order = 0;
  Offset pos = Offset.zero; // 布局后中心坐标（归一化 0~1）
}

class _MEdge {
  _MEdge(this.from, this.to, this.label);
  final String from;
  final String to;
  final String? label;
}

class _MermaidGraph {
  _MermaidGraph(this.horizontal, this.nodes, this.edges);

  final bool horizontal;
  final Map<String, _MNode> nodes;
  final List<_MEdge> edges;

  static _MermaidGraph parse(String src) {
    bool horizontal = false;
    final nodes = <String, _MNode>{};
    final edges = <_MEdge>[];

    _MNode nodeFor(String token) {
      // 支持 A、A[文本]、A(文本)、A{文本}、A["文本"]（带引号与 <br/>）
      final m = RegExp(r'^([\w\u4e00-\u9fa5]+)[\[\(\{]?([^\]\)\}]*)[\]\)\}]?$')
          .firstMatch(token.trim());
      final id = m?.group(1) ?? token.trim();
      var label = (m?.group(2) ?? '').trim();
      label = label
          .replaceAll('"', '')
          .replaceAll('<br/>', '\n')
          .replaceAll('<br>', '\n')
          .trim();
      if (label.isEmpty) label = id;
      return nodes.putIfAbsent(id, () => _MNode(id, label));
    }

    for (final raw in src.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('%%')) continue;
      if (RegExp(r'^graph\s+LR|^flowchart\s+LR').hasMatch(line)) {
        horizontal = true;
        continue;
      }
      if (RegExp(r'^graph\s+TD|^graph\s+TB|^flowchart\s+TD|^flowchart\s+TB')
          .hasMatch(line)) {
        continue;
      }
      // 边：A --> B / A -->|标签| B / A -- 标签 --> B / A --- B
      final edge = RegExp(
          r'([\w\u4e00-\u9fa5]+(?:\[[^\]]*\]|\([^)]*\)|\{[^}*\}])?)\s*-{2,3}>\s*(?:\|([^|]*)\|\s*)?([\w\u4e00-\u9fa5]+(?:\[[^\]]*\]|\([^)]*\)|\{[^}*\}])?)');
      final m = edge.firstMatch(line);
      if (m != null) {
        final fromToken = m.group(1);
        final toToken = m.group(3);
        if (fromToken == null || toToken == null) continue;
        final a = nodeFor(fromToken);
        final b = nodeFor(toToken);
        var lbl = (m.group(2) ?? '').trim();
        lbl = lbl.replaceAll('"', '').replaceAll('<br/>', '\n').trim();
        edges.add(_MEdge(a.id, b.id, lbl.isEmpty ? null : lbl));
        continue;
      }
      // 无箭头连线：A --- B
      final dash = RegExp(
          r'([\w\u4e00-\u9fa5]+(?:\[[^\]]*\])?)\s*-{3}\s*([\w\u4e00-\u9fa5]+(?:\[[^\]]*\])?)');
      final md = dash.firstMatch(line);
      if (md != null) {
        final fromToken = md.group(1);
        final toToken = md.group(2);
        if (fromToken == null || toToken == null) continue;
        edges.add(_MEdge(nodeFor(fromToken).id, nodeFor(toToken).id, null));
        continue;
      }
      // 单节点声明：A[文本]
      if (RegExp(r'^[\w\u4e00-\u9fa5]+[\[\(\{]').hasMatch(line)) {
        nodeFor(line);
      }
    }

    // 层级布局：BFS 定 level；同层按出现顺序排 order。
    for (final n in nodes.values) {
      n.level = -1;
    }
    final queue = <String>[];
    for (final e in edges) {
      final fromNode = nodes[e.from];
      if (fromNode == null) continue;
      if (fromNode.level == -1) {
        fromNode.level = 0;
      }
      if (!queue.contains(e.from)) queue.add(e.from);
    }
    if (queue.isEmpty && nodes.isNotEmpty) {
      queue.add(nodes.keys.first);
      nodes.values.first.level = 0;
    }
    var qi = 0;
    while (qi < queue.length) {
      final cur = nodes[queue[qi++]];
      if (cur == null) continue;
      final curId = cur.id;
      for (final e in edges.where((e) => e.from == curId)) {
        final nxt = nodes[e.to];
        if (nxt == null) continue;
        if (nxt.level == -1) {
          nxt.level = cur.level + 1;
          queue.add(nxt.id);
        } else if (nxt.level <= cur.level) {
          nxt.level = cur.level + 1;
        }
      }
    }
    for (final n in nodes.values) {
      if (n.level == -1) n.level = 0;
    }
    // 同层排序
    final byLevel = <int, List<_MNode>>{};
    for (final n in nodes.values) {
      byLevel.putIfAbsent(n.level, () => []).add(n);
    }
    for (final list in byLevel.values) {
      for (var i = 0; i < list.length; i++) {
        list[i].order = i;
      }
    }
    // 归一化坐标
    var maxLevel = 0;
    for (final level in byLevel.keys) {
      if (level > maxLevel) maxLevel = level;
    }
    final levelSpan = maxLevel == 0 ? 1 : maxLevel;
    for (final list in byLevel.values) {
      final rowSpan = list.isEmpty ? 1 : list.length;
      for (final n in list) {
        if (horizontal) {
          n.pos = Offset(n.level / levelSpan, (n.order + 0.5) / rowSpan);
        } else {
          n.pos = Offset((n.order + 0.5) / rowSpan, n.level / levelSpan);
        }
      }
    }
    return _MermaidGraph(horizontal, nodes, edges);
  }
}

class _MermaidPainter extends CustomPainter {
  _MermaidPainter({required this.graph});

  final _MermaidGraph graph;

  @override
  void paint(Canvas canvas, Size size) {
    final scheme = _schemeOf(canvas);
    final nodePaint = Paint()..color = scheme.node;
    final border = Paint()
      ..color = scheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final arrow = Paint()
      ..color = scheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    Rect nodeRect(_MNode n) {
      const w = 76.0, h = 26.0;
      final c = Offset(8 + n.pos.dx * (size.width - 16 - w),
          8 + n.pos.dy * (size.height - 16 - h));
      return Rect.fromCenter(center: c + const Offset(w / 2, h / 2), width: w, height: h);
    }

    // 边
    for (final e in graph.edges) {
      final fromNode = graph.nodes[e.from];
      final toNode = graph.nodes[e.to];
      if (fromNode == null || toNode == null) continue;
      final a = nodeRect(fromNode);
      final b = nodeRect(toNode);
      Offset start, end;
      if (graph.horizontal) {
        start = Offset(a.right, a.center.dy);
        end = Offset(b.left, b.center.dy);
      } else {
        start = Offset(a.center.dx, a.bottom);
        end = Offset(b.center.dx, b.top);
      }
      if ((start - end).distance < 4) continue;
      canvas.drawLine(start, end, arrow);
      // 箭头头部
      final dir = (end - start) / (end - start).distance;
      final perp = Offset(-dir.dy, dir.dx);
      canvas.drawLine(end, end - dir * 7 + perp * 3.5, arrow);
      canvas.drawLine(end, end - dir * 7 - perp * 3.5, arrow);
      // 边标签：空标签不画，避免对 null 做强解包。
      final label = e.label;
      if (label != null && label.isNotEmpty) {
        _text(canvas, label, (start + end) / 2 + const Offset(0, -12),
            size.width, 9, scheme.edgeLabel);
      }
    }

    // 节点
    for (final n in graph.nodes.values) {
      final r = nodeRect(n);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(6));
      canvas.drawRRect(rr, nodePaint);
      canvas.drawRRect(rr, border);
      _text(canvas, n.label, Offset(r.left, r.top + 6), r.width, 10,
          scheme.nodeText);
    }
  }

  void _text(Canvas canvas, String t, Offset at, double maxWidth,
      double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: t,
          style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, at);
  }

  _Scheme _schemeOf(Canvas canvas) => const _Scheme();

  @override
  bool shouldRepaint(covariant _MermaidPainter old) => old.graph != graph;
}

class _Scheme {
  const _Scheme();
  Color get node => const Color(0x223D7EFF);
  Color get border => const Color(0xFF3D7EFF);
  Color get nodeText => const Color(0xFF1B3B6F);
  Color get edgeLabel => const Color(0xFF8A6D1A);
}