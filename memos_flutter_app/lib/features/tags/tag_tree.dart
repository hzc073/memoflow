import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';
import '../../state/memos/memos_providers.dart';

class TagTreeNode {
  TagTreeNode({
    required this.key,
    required this.path,
    required this.count,
    this.tagId,
    this.parentId,
    this.pinned = false,
    this.colorHex,
    this.effectiveColorHex,
    this.lastUsedTimeSec,
    List<TagTreeNode>? children,
  }) : children = children ?? [];

  final String key;
  final String path;
  final int? tagId;
  final int? parentId;
  final bool pinned;
  final String? colorHex;
  String? effectiveColorHex;
  final int? lastUsedTimeSec;
  int count;
  final List<TagTreeNode> children;

  TagTreeNode copyWithChildren(List<TagTreeNode> nextChildren) {
    return TagTreeNode(
      key: key,
      path: path,
      count: count,
      tagId: tagId,
      parentId: parentId,
      pinned: pinned,
      colorHex: colorHex,
      effectiveColorHex: effectiveColorHex,
      lastUsedTimeSec: lastUsedTimeSec,
      children: nextChildren,
    );
  }
}

class TagTreeFilterResult {
  const TagTreeFilterResult({
    required this.nodes,
    required this.autoExpandedPaths,
  });

  final List<TagTreeNode> nodes;
  final Set<String> autoExpandedPaths;
}

enum TagTreeMenuAction { edit, delete }

List<TagTreeNode> buildTagTree(
  List<TagStat> stats, {
  int Function(TagTreeNode a, TagTreeNode b)? comparator,
}) {
  final cleaned = stats
      .where((s) => s.tag.trim().isNotEmpty)
      .toList(growable: false);
  if (cleaned.isEmpty) return const [];

  final nodesByPath = <String, TagTreeNode>{};
  final nodesById = <int, TagTreeNode>{};

  for (final stat in cleaned) {
    final path = stat.path.trim();
    if (path.isEmpty) continue;
    final key = path.contains('/') ? path.split('/').last : path;
    final existing = nodesByPath[path];
    final node =
        existing ??
        TagTreeNode(
          key: key,
          path: path,
          count: 0,
          tagId: stat.tagId,
          parentId: stat.parentId,
          pinned: stat.pinned,
          colorHex: stat.colorHex,
          lastUsedTimeSec: stat.lastUsedTimeSec,
        );
    if (existing == null) {
      nodesByPath[path] = node;
    }
    node.count = stat.count;
    node.effectiveColorHex ??= stat.colorHex;
    if (stat.tagId != null) {
      nodesById[stat.tagId!] = node;
    }
  }

  final rootNodes = <TagTreeNode>[];
  final attached = <String>{};

  for (final node in nodesById.values) {
    final parentId = node.parentId;
    if (parentId != null && nodesById.containsKey(parentId)) {
      nodesById[parentId]!.children.add(node);
    } else {
      rootNodes.add(node);
    }
    attached.add(node.path);
  }

  for (final node in nodesByPath.values) {
    if (attached.contains(node.path)) continue;
    _attachByPath(node, nodesByPath, rootNodes, attached);
  }

  _applyInheritedColors(rootNodes, null);
  _sortNodes(rootNodes, comparator);
  return rootNodes;
}

TagTreeFilterResult filterTagTree(
  List<TagTreeNode> nodes,
  bool Function(TagTreeNode node) predicate,
) {
  final result = <TagTreeNode>[];
  final autoExpandedPaths = <String>{};

  TagTreeNode? visit(TagTreeNode node) {
    final filteredChildren = <TagTreeNode>[];
    for (final child in node.children) {
      final filteredChild = visit(child);
      if (filteredChild != null) {
        filteredChildren.add(filteredChild);
      }
    }

    final matches = predicate(node);
    if (!matches && filteredChildren.isEmpty) {
      return null;
    }
    if (filteredChildren.isNotEmpty) {
      autoExpandedPaths.add(node.path);
    }
    return node.copyWithChildren(filteredChildren);
  }

  for (final node in nodes) {
    final filteredNode = visit(node);
    if (filteredNode != null) {
      result.add(filteredNode);
    }
  }

  return TagTreeFilterResult(
    nodes: result,
    autoExpandedPaths: autoExpandedPaths,
  );
}

Set<String> collectAncestorTagPaths(String? path, {bool includeSelf = true}) {
  final trimmed = path?.trim() ?? '';
  if (trimmed.isEmpty) return const <String>{};
  final segments = trimmed.split('/');
  final result = <String>{};
  final limit = includeSelf ? segments.length : segments.length - 1;
  for (var i = 0; i < limit; i++) {
    result.add(segments.take(i + 1).join('/'));
  }
  return result;
}

void _sortNodes(
  List<TagTreeNode> nodes,
  int Function(TagTreeNode a, TagTreeNode b)? comparator,
) {
  nodes.sort((a, b) {
    if (comparator != null) {
      final result = comparator(a, b);
      if (result != 0) return result;
    }
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return a.key.compareTo(b.key);
  });
  for (final node in nodes) {
    if (node.children.isNotEmpty) {
      _sortNodes(node.children, comparator);
    }
  }
}

void _attachByPath(
  TagTreeNode node,
  Map<String, TagTreeNode> nodesByPath,
  List<TagTreeNode> rootNodes,
  Set<String> attached,
) {
  if (attached.contains(node.path)) return;
  if (!node.path.contains('/')) {
    rootNodes.add(node);
    attached.add(node.path);
    return;
  }
  final parentPath = node.path.substring(0, node.path.lastIndexOf('/'));
  final parentNode = nodesByPath.putIfAbsent(
    parentPath,
    () => TagTreeNode(
      key: parentPath.split('/').last,
      path: parentPath,
      count: 0,
    ),
  );
  parentNode.children.add(node);
  attached.add(node.path);
  if (!attached.contains(parentNode.path)) {
    _attachByPath(parentNode, nodesByPath, rootNodes, attached);
  }
}

void _applyInheritedColors(List<TagTreeNode> nodes, String? inheritedHex) {
  for (final node in nodes) {
    final own = node.colorHex;
    final resolved = own != null && own.trim().isNotEmpty ? own : inheritedHex;
    node.effectiveColorHex = resolved;
    if (node.children.isNotEmpty) {
      _applyInheritedColors(node.children, resolved);
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
    this.showCount = true,
    this.compact = false,
    this.selectedPath,
    this.showSelectedLeadingCheck = false,
    this.showMenu = false,
    this.onMenuAction,
    this.expandedPaths = const <String>{},
    this.onToggleExpanded,
  });

  final List<TagTreeNode> nodes;
  final ValueChanged<String> onSelect;
  final Color textMain;
  final Color textMuted;
  final bool showCount;
  final bool compact;
  final String? selectedPath;
  final bool showSelectedLeadingCheck;
  final bool showMenu;
  final void Function(TagTreeNode node, TagTreeMenuAction action)? onMenuAction;
  final Set<String> expandedPaths;
  final ValueChanged<String>? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final node in nodes)
          _TagTreeItem(
            node: node,
            depth: 0,
            onSelect: onSelect,
            textMain: textMain,
            textMuted: textMuted,
            showCount: showCount,
            compact: compact,
            selectedPath: selectedPath,
            showSelectedLeadingCheck: showSelectedLeadingCheck,
            showMenu: showMenu,
            onMenuAction: onMenuAction,
            expandedPaths: expandedPaths,
            onToggleExpanded: onToggleExpanded,
          ),
      ],
    );
  }
}

class _TagTreeItem extends StatelessWidget {
  const _TagTreeItem({
    required this.node,
    required this.depth,
    required this.onSelect,
    required this.textMain,
    required this.textMuted,
    required this.showCount,
    required this.compact,
    required this.selectedPath,
    required this.showSelectedLeadingCheck,
    required this.showMenu,
    required this.onMenuAction,
    required this.expandedPaths,
    required this.onToggleExpanded,
  });

  final TagTreeNode node;
  final int depth;
  final ValueChanged<String> onSelect;
  final Color textMain;
  final Color textMuted;
  final bool showCount;
  final bool compact;
  final String? selectedPath;
  final bool showSelectedLeadingCheck;
  final bool showMenu;
  final void Function(TagTreeNode node, TagTreeMenuAction action)? onMenuAction;
  final Set<String> expandedPaths;
  final ValueChanged<String>? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = hasChildren && expandedPaths.contains(node.path);
    final normalizedSelectedPath = selectedPath?.trim();
    final isSelected =
        normalizedSelectedPath != null &&
        normalizedSelectedPath.isNotEmpty &&
        normalizedSelectedPath == node.path;
    final indent = compact ? 12.0 : 16.0;
    final leadingSize = compact ? 18.0 : 20.0;
    final neutralColor = textMuted;
    final row = InkWell(
      borderRadius: BorderRadius.circular(compact ? 10 : 12),
      onTap: () => onSelect(node.path),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 6,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          children: [
            SizedBox(
              width: leadingSize,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _LeadingMarker(
                  compact: compact,
                  isSelected: isSelected,
                  showSelectedLeadingCheck: showSelectedLeadingCheck,
                  color: neutralColor,
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Text(
                node.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 14 : 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: textMain,
                ),
              ),
            ),
            if (showCount) ...[
              const SizedBox(width: 8),
              Text(
                '${node.count}',
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  color: neutralColor,
                ),
              ),
            ],
            if (hasChildren)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onToggleExpanded?.call(node.path),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.chevron_right,
                      size: compact ? 18 : 20,
                      color: neutralColor,
                    ),
                  ),
                ),
              ),
            if (showMenu && node.tagId != null && onMenuAction != null)
              PopupMenuButton<TagTreeMenuAction>(
                icon: Icon(
                  Icons.more_horiz,
                  size: compact ? 18 : 20,
                  color: neutralColor,
                ),
                onSelected: (action) => onMenuAction?.call(node, action),
                itemBuilder: (context) => [
                  PopupMenuItem<TagTreeMenuAction>(
                    value: TagTreeMenuAction.edit,
                    child: Text(context.t.strings.legacy.msg_edit_tag),
                  ),
                  PopupMenuItem<TagTreeMenuAction>(
                    value: TagTreeMenuAction.delete,
                    child: Text(context.t.strings.legacy.msg_delete_tag),
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    if (!hasChildren) {
      return Padding(
        padding: EdgeInsets.only(left: depth * indent),
        child: row,
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: depth * indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row,
          if (isExpanded)
            Container(
              margin: EdgeInsets.only(left: indent),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: textMuted.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final child in node.children)
                    _TagTreeItem(
                      node: child,
                      depth: depth + 1,
                      onSelect: onSelect,
                      textMain: textMain,
                      textMuted: textMuted,
                      showCount: showCount,
                      compact: compact,
                      selectedPath: selectedPath,
                      showSelectedLeadingCheck: showSelectedLeadingCheck,
                      showMenu: showMenu,
                      onMenuAction: onMenuAction,
                      expandedPaths: expandedPaths,
                      onToggleExpanded: onToggleExpanded,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LeadingMarker extends StatelessWidget {
  const _LeadingMarker({
    required this.compact,
    required this.isSelected,
    required this.showSelectedLeadingCheck,
    required this.color,
  });

  final bool compact;
  final bool isSelected;
  final bool showSelectedLeadingCheck;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (showSelectedLeadingCheck && isSelected) {
      return Icon(
        Icons.check,
        size: compact ? 16 : 18,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return Text(
      '#',
      style: TextStyle(
        fontSize: compact ? 16 : 18,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
  }
}
