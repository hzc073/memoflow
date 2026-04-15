import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tag_badge.dart';
import '../../core/tag_colors.dart';
import '../../i18n/strings.g.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/tags/tag_color_lookup.dart';
import '../../state/tags/tag_repository.dart';

Future<bool> confirmAndDeleteTag({
  required BuildContext context,
  required WidgetRef ref,
  required TagStat tag,
  VoidCallback? onDeleted,
}) async {
  final tagId = tag.tagId ?? 0;
  if (tagId <= 0) return false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t.strings.legacy.msg_delete_tag_confirm),
      content: Text(context.t.strings.legacy.msg_delete_tag_warning),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.t.strings.common.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.t.strings.common.confirm),
        ),
      ],
    ),
  );
  if (ok != true) return false;

  try {
    await ref.read(tagRepositoryProvider).deleteTag(tagId);
    onDeleted?.call();
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t.strings.legacy.msg_save_failed_3(e: e)),
      ),
    );
    return false;
  }
}

class TagEditSheet extends ConsumerStatefulWidget {
  const TagEditSheet({super.key, this.tag});

  final TagStat? tag;

  static Future<void> showEditorDialog(BuildContext context, {TagStat? tag}) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: TagEditSheet(tag: tag),
      ),
    );
  }

  @override
  ConsumerState<TagEditSheet> createState() => _TagEditSheetState();
}

class _TagEditSheetState extends ConsumerState<TagEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _parentId;
  bool _pinned = false;
  String? _colorHex;
  bool _saving = false;

  static const _presetColors = <String>[
    '#EF4444',
    '#F97316',
    '#F59E0B',
    '#84CC16',
    '#22C55E',
    '#14B8A6',
    '#0EA5E9',
    '#3B82F6',
    '#6366F1',
    '#8B5CF6',
    '#EC4899',
    '#64748B',
  ];

  @override
  void initState() {
    super.initState();
    final tag = widget.tag;
    if (tag != null) {
      _nameController.text = tag.path.split('/').last;
      _parentId = tag.parentId;
      _pinned = tag.pinned;
      _colorHex = normalizeTagColorHex(tag.colorHex);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = widget.tag;
    final isDark = theme.brightness == Brightness.dark;
    final tagStats =
        ref.watch(tagStatsProvider).valueOrNull ?? const <TagStat>[];
    final colorLookup = ref.watch(tagColorLookupProvider);
    final invalidParentIds = _collectDescendants(tagStats, tag?.tagId);
    final availableParents =
        tagStats
            .where((item) => item.tagId != null && item.tagId != tag?.tagId)
            .where((item) => !invalidParentIds.contains(item.tagId))
            .toList(growable: false)
          ..sort((a, b) => a.path.compareTo(b.path));

    final parentPath = tagStats
        .firstWhere(
          (item) => item.tagId == _parentId,
          orElse: () => const TagStat(tag: '', count: 0),
        )
        .path;
    final inheritedColorHex = _parentId == null || parentPath.trim().isEmpty
        ? null
        : colorLookup.resolveEffectiveHexByPath(parentPath);
    final selectedHex = normalizeTagColorHex(_colorHex);
    final effectiveHex = selectedHex ?? inheritedColorHex;
    final previewColor =
        parseTagColor(effectiveHex) ?? theme.colorScheme.primary;
    final previewColors = buildTagChipColors(
      baseColor: previewColor,
      surfaceColor: theme.colorScheme.surface,
      isDark: isDark,
    );
    final title = tag == null
        ? context.t.strings.legacy.msg_create_tag
        : context.t.strings.legacy.msg_edit_tag;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _nameController,
                  autofocus: tag == null,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.t.strings.legacy.msg_tag_name,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return context.t.strings.legacy.msg_tag_name_required;
                    }
                    if (trimmed.contains('/')) {
                      return context.t.strings.legacy.msg_tag_name_invalid;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: context.t.strings.legacy.msg_parent_tag,
                  border: const OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _parentId,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(context.t.strings.legacy.msg_no_parent),
                      ),
                      for (final item in availableParents)
                        DropdownMenuItem<int?>(
                          value: item.tagId,
                          child: Text('#${item.path}'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _parentId = value),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    context.t.strings.legacy.msg_tag_color,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _colorHex = null),
                    child: Text(context.t.strings.legacy.msg_inherit),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_colorHex == null && inheritedColorHex != null)
                    TagBadge(
                      label: context.t.strings.legacy.msg_inherit_color,
                      colors: previewColors,
                      compact: true,
                    ),
                  TagBadge(
                    label:
                        effectiveHex ??
                        '#${previewColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    colors: previewColors,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final hex in _presetColors)
                    _ColorSwatch(
                      color: parseTagColor(hex)!,
                      selected: selectedHex == hex,
                      onTap: () => setState(() => _colorHex = hex),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.t.strings.legacy.msg_custom,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _TagColorPicker(
                color: _resolveEditorColor(context, inheritedColorHex),
                border: theme.colorScheme.outlineVariant,
                onChanged: (color) =>
                    setState(() => _colorHex = _colorToHex(color)),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t.strings.legacy.msg_tag_pinned),
                value: _pinned,
                onChanged: (value) => setState(() => _pinned = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (tag != null)
                    TextButton.icon(
                      onPressed: _saving
                          ? null
                          : () => confirmAndDeleteTag(
                              context: context,
                              ref: ref,
                              tag: tag,
                              onDeleted: () {
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                            ),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.t.strings.legacy.msg_delete_tag),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(context.t.strings.common.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.t.strings.common.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _resolveEditorColor(BuildContext context, String? inheritedColorHex) {
    return parseTagColor(_colorHex) ??
        parseTagColor(inheritedColorHex) ??
        Theme.of(context).colorScheme.primary;
  }

  String _colorToHex(Color color) {
    final value = color.toARGB32() & 0x00FFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Set<int> _collectDescendants(List<TagStat> tags, int? rootId) {
    if (rootId == null) return const <int>{};
    final children = <int, List<int>>{};
    for (final tag in tags) {
      final id = tag.tagId;
      final parent = tag.parentId;
      if (id == null || parent == null) continue;
      children.putIfAbsent(parent, () => <int>[]).add(id);
    }
    final result = <int>{};
    final stack = <int>[rootId];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final kids = children[current] ?? const <int>[];
      for (final child in kids) {
        if (result.add(child)) {
          stack.add(child);
        }
      }
    }
    return result;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(tagRepositoryProvider);
    final name = _nameController.text.trim();
    try {
      if (widget.tag == null) {
        await repo.createTag(
          name: name,
          parentId: _parentId,
          pinned: _pinned,
          colorHex: _colorHex,
        );
      } else {
        await repo.updateTag(
          id: widget.tag!.tagId ?? 0,
          name: name,
          parentId: _parentId,
          pinned: _pinned,
          colorHex: _colorHex,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.strings.legacy.msg_save_failed_3(e: e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2),
        ),
      ),
    );
  }
}

class _TagColorPicker extends StatelessWidget {
  const _TagColorPicker({
    required this.color,
    required this.border,
    required this.onChanged,
  });

  final Color color;
  final Color border;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    return Column(
      children: [
        Container(
          height: 176,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _TagLightnessSaturationPalette(
              color: color,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: ColorPickerSlider(
              TrackType.hue,
              hsv,
              (next) => onChanged(next.toColor()),
              displayThumbColor: true,
              fullThumbColor: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _TagLightnessSaturationPalette extends StatelessWidget {
  const _TagLightnessSaturationPalette({
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  void _handleOffset(Offset localPosition, Size size, HSLColor hsl) {
    if (size.width <= 0 || size.height <= 0) return;
    final dx = localPosition.dx.clamp(0.0, size.width);
    final dy = localPosition.dy.clamp(0.0, size.height);
    final saturation = (dx / size.width).clamp(0.0, 1.0);
    final lightness = (1 - dy / size.height).clamp(0.0, 1.0);
    onChanged(
      hsl.withSaturation(saturation).withLightness(lightness).toColor(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        final size = Size(width, height);
        return GestureDetector(
          onPanDown: (details) =>
              _handleOffset(details.localPosition, size, hsl),
          onPanUpdate: (details) =>
              _handleOffset(details.localPosition, size, hsl),
          child: CustomPaint(
            size: size,
            painter: _TagLightnessSaturationPainter(hsl),
          ),
        );
      },
    );
  }
}

class _TagLightnessSaturationPainter extends CustomPainter {
  _TagLightnessSaturationPainter(this.hsl);

  final HSLColor hsl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;
    final saturationGradient = LinearGradient(
      colors: [
        const Color(0xFF808080),
        HSLColor.fromAHSL(1.0, hsl.hue, 1.0, 0.5).toColor(),
      ],
    );
    const lightnessGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, 0.5, 0.5, 1],
      colors: [
        Colors.white,
        Color(0x00FFFFFF),
        Colors.transparent,
        Colors.black,
      ],
    );
    canvas.drawRect(
      rect,
      Paint()..shader = saturationGradient.createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()..shader = lightnessGradient.createShader(rect),
    );

    final pointer = Offset(
      size.width * hsl.saturation,
      size.height * (1 - hsl.lightness),
    );
    final pointerColor = useWhiteForeground(hsl.toColor())
        ? Colors.white
        : Colors.black;
    canvas.drawCircle(
      pointer,
      size.height * 0.04,
      Paint()
        ..color = pointerColor
        ..strokeWidth = 1.5
        ..blendMode = BlendMode.luminosity
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TagLightnessSaturationPainter oldDelegate) {
    return oldDelegate.hsl != hsl;
  }
}
