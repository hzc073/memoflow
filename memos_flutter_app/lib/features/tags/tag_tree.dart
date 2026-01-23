import 'package:flutter/material.dart';

import '../../core/memoflow_palette.dart';
import '../../state/memos_providers.dart';

class TagTreeNode {
  TagTreeNode({
    required this.key,
    required this.text,
    required this.count,
    List<TagTreeNode>? children,
  }) : children = children ?? [];

  final String key;
  final String text;
  int count;
  final List<TagTreeNode> children;
}

List<TagTreeNode> buildTagTree(List<TagStat> stats) {
  final cleaned = stats.where((s) => s.tag.trim().isNotEmpty).toList(growable: false);
  final counts = <String, int>{};
  for (final stat in cleaned) {
    counts[stat.tag.trim()] = stat.count;
  }

  final sorted = [...cleaned]..sort((a, b) => a.tag.compareTo(b.tag));
  final root = TagTreeNode(key: '', text: '', count: 0);

  for (final stat in sorted) {
    final raw = stat.tag.trim();
    if (raw.isEmpty) continue;
    final parts = raw.split('/').where((p) => p.trim().isNotEmpty).toList(growable: false);
    if (parts.isEmpty) continue;

    var current = root;
    var path = '';
    for (var i = 0; i < parts.length; i++) {
      final key = parts[i].trim();
      if (key.isEmpty) continue;
      path = path.isEmpty ? key : '$path/$key';
      TagTreeNode? node;
      for (final child in current.children) {
        if (child.text == path) {
          node = child;
          break;
        }
      }
      if (node == null) {
        node = TagTreeNode(
          key: key,
          text: path,
          count: counts[path] ?? 0,
        );
        current.children.add(node);
      } else if (node.count == 0) {
        node.count = counts[path] ?? node.count;
      }
      current = node;
    }
  }

  _sortNodes(root.children);
  return root.children;
}

void _sortNodes(List<TagTreeNode> nodes) {
  nodes.sort((a, b) => a.text.compareTo(b.text));
  for (final node in nodes) {
    if (node.children.isNotEmpty) {
      _sortNodes(node.children);
    }
  }
}

class TagTreeList extends StatelessWidget {
  const TagTreeList({
    super.key,
    required this.nodes,
    required this.onSelect,
    required this.textMain,
    required this.textMuted,
    this.showCount = false,
    this.initiallyExpanded = true,
    this.compact = false,
  });

  final List<TagTreeNode> nodes;
  final ValueChanged<String> onSelect;
  final Color textMain;
  final Color textMuted;
  final bool showCount;
  final bool initiallyExpanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        for (final node in nodes)
          _TagTreeItem(
            node: node,
            depth: 0,
            onSelect: onSelect,
            textMain: textMain,
            textMuted: textMuted,
            showCount: showCount,
            initiallyExpanded: initiallyExpanded,
            compact: compact,
          ),
      ],
    );
  }
}

class _TagTreeItem extends StatefulWidget {
  const _TagTreeItem({
    required this.node,
    required this.depth,
    required this.onSelect,
    required this.textMain,
    required this.textMuted,
    required this.showCount,
    required this.initiallyExpanded,
    required this.compact,
  });

  final TagTreeNode node;
  final int depth;
  final ValueChanged<String> onSelect;
  final Color textMain;
  final Color textMuted;
  final bool showCount;
  final bool initiallyExpanded;
  final bool compact;

  @override
  State<_TagTreeItem> createState() => _TagTreeItemState();
}

class _TagTreeItemState extends State<_TagTreeItem> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant _TagTreeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.text != widget.node.text) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final indent = widget.compact ? 10.0 : 14.0;
    final vertical = widget.compact ? 8.0 : 10.0;
    final iconSize = widget.compact ? 18.0 : 20.0;
    final label = '#${node.key}';
    final count = widget.showCount && node.count > 1 ? ' (${node.count})' : '';
    final accent = MemoFlowPalette.primary;

    final row = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => widget.onSelect(node.text),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: vertical),
        child: Row(
          children: [
            Icon(Icons.tag, size: iconSize, color: widget.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label$count',
                style: TextStyle(fontWeight: FontWeight.w600, color: widget.textMain),
              ),
            ),
            if (hasChildren)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 160),
                  child: Icon(Icons.chevron_right, size: 18, color: widget.textMuted),
                ),
              ),
          ],
        ),
      ),
    );

    if (!hasChildren) {
      return Padding(
        padding: EdgeInsets.only(left: widget.depth * indent),
        child: row,
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: widget.depth * indent),
      child: Column(
        children: [
          row,
          if (_expanded)
            Container(
              margin: EdgeInsets.only(left: indent),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: accent.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  for (final child in node.children)
                    _TagTreeItem(
                      node: child,
                      depth: widget.depth + 1,
                      onSelect: widget.onSelect,
                      textMain: widget.textMain,
                      textMuted: widget.textMuted,
                      showCount: widget.showCount,
                      initiallyExpanded: widget.initiallyExpanded,
                      compact: widget.compact,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
