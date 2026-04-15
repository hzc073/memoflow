import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/app_localization.dart';
import '../../core/measure_size.dart';
import '../../core/memoflow_palette.dart';
import '../../core/uid.dart';
import '../../data/models/attachment.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_collection.dart';
import '../../data/repositories/collections_repository.dart';
import '../../i18n/strings.g.dart';
import '../../state/collections/collection_resolver.dart';
import '../../state/collections/collections_provider.dart';
import '../../state/memos/memos_providers.dart';
import '../../state/tags/tag_color_lookup.dart';
import 'collection_ui.dart';

class CollectionEditorScreen extends ConsumerStatefulWidget {
  const CollectionEditorScreen({
    super.key,
    this.initialCollection,
    this.initialType,
    this.initialSelectedTags = const <String>[],
    this.initialManualMemoUids = const <String>[],
  });

  final MemoCollection? initialCollection;
  final MemoCollectionType? initialType;
  final List<String> initialSelectedTags;
  final List<String> initialManualMemoUids;

  @override
  ConsumerState<CollectionEditorScreen> createState() =>
      _CollectionEditorScreenState();
}

class _CollectionEditorScreenState
    extends ConsumerState<CollectionEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final Set<String> _selectedTags = <String>{};
  final List<String> _manualMemoUids = <String>[];
  late MemoCollectionType _type;
  late CollectionTagMatchMode _tagMatchMode;
  late bool _includeDescendants;
  late CollectionVisibilityScope _visibility;
  late CollectionDateRule _dateRule;
  late CollectionAttachmentRule _attachmentRule;
  late bool _pinnedOnly;
  late String _iconKey;
  String? _accentColorHex;
  late CollectionCoverMode _coverMode;
  String? _coverMemoUid;
  String? _coverAttachmentUid;
  late CollectionLayoutMode _layoutMode;
  late CollectionSectionMode _sectionMode;
  late CollectionSortMode _sortMode;
  late bool _showStats;
  late bool _hideWhenEmpty;
  bool _hasExplicitManualMemoSelection = false;
  bool _hasLocalChanges = false;
  double _bottomBarHeight = 120;

  bool get _isEditing => widget.initialCollection != null;

  @override
  void initState() {
    super.initState();
    final collection = widget.initialCollection;
    final initialSelectedTags = widget.initialSelectedTags
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    _type = collection?.type ?? widget.initialType ?? MemoCollectionType.smart;
    _manualMemoUids.addAll(
      widget.initialManualMemoUids
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
    _titleController.text = collection?.title ?? '';
    _descriptionController.text = collection?.description ?? '';
    _selectedTags.addAll(
      collection?.rules.normalizedTagPaths ?? initialSelectedTags,
    );
    if (collection == null &&
        _type == MemoCollectionType.smart &&
        _titleController.text.trim().isEmpty &&
        initialSelectedTags.length == 1) {
      _titleController.text = initialSelectedTags.first;
    }
    _tagMatchMode =
        collection?.rules.tagMatchMode ?? CollectionTagMatchMode.any;
    _includeDescendants = collection?.rules.includeDescendants ?? true;
    _visibility = collection?.rules.visibility ?? CollectionVisibilityScope.all;
    _dateRule = collection?.rules.dateRule ?? CollectionDateRule.defaults;
    _attachmentRule =
        collection?.rules.attachmentRule ?? CollectionAttachmentRule.any;
    _pinnedOnly = collection?.rules.pinnedOnly ?? false;
    _iconKey = collection?.iconKey ?? MemoCollection.defaultIconKey;
    _accentColorHex = collection?.accentColorHex;
    if (collection == null &&
        _accentColorHex == null &&
        initialSelectedTags.isNotEmpty) {
      _accentColorHex = ref
          .read(tagColorLookupProvider)
          .resolveEffectiveHexByPath(initialSelectedTags.first);
    }
    _coverMode = collection?.cover.mode ?? CollectionCoverMode.auto;
    _coverMemoUid = collection?.cover.memoUid;
    _coverAttachmentUid = collection?.cover.attachmentUid;
    _layoutMode = collection?.view.defaultLayout ?? CollectionLayoutMode.shelf;
    _sectionMode = collection?.view.sectionMode ?? CollectionSectionMode.none;
    _sortMode =
        collection?.view.sortMode ??
        (_type == MemoCollectionType.manual
            ? CollectionSortMode.manualOrder
            : CollectionSortMode.displayTimeDesc);
    _showStats = collection?.view.showStats ?? true;
    _hideWhenEmpty = collection?.hideWhenEmpty ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  CollectionRuleSet get _draftRules => CollectionRuleSet(
    tagPaths: _selectedTags.toList(growable: false)..sort(),
    tagMatchMode: _tagMatchMode,
    includeDescendants: _includeDescendants,
    visibility: _visibility,
    dateRule: _dateRule,
    attachmentRule: _attachmentRule,
    pinnedOnly: _pinnedOnly,
  );

  MemoCollection get _draftCollection {
    final initial = widget.initialCollection;
    final now = DateTime.now();
    final view = CollectionViewPreferences(
      defaultLayout: _layoutMode,
      sectionMode: _sectionMode,
      sortMode: _sortMode,
      showStats: _showStats,
    );
    return MemoCollection(
      id: initial?.id ?? generateUid(length: 16),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _type,
      iconKey: _iconKey,
      accentColorHex: _accentColorHex,
      rules: _type == MemoCollectionType.smart
          ? _draftRules
          : CollectionRuleSet.defaults,
      cover: CollectionCoverSpec(
        mode: _coverMode,
        memoUid: _coverMode == CollectionCoverMode.attachment
            ? _coverMemoUid
            : null,
        attachmentUid: _coverMode == CollectionCoverMode.attachment
            ? _coverAttachmentUid
            : null,
        iconKey: _coverMode == CollectionCoverMode.icon ? _iconKey : null,
      ),
      view: view,
      pinned: initial?.pinned ?? false,
      archived: initial?.archived ?? false,
      hideWhenEmpty: _hideWhenEmpty,
      sortOrder: initial?.sortOrder ?? 0,
      createdTime: initial?.createdTime ?? now,
      updatedTime: now,
    );
  }

  Future<void> _save({required List<LocalMemo> existingManualItems}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage(context.t.strings.collections.titleRequired);
      return;
    }
    if (_type == MemoCollectionType.smart && !_draftRules.hasAnyConstraint) {
      _showMessage(context.t.strings.collections.ruleRequired);
      return;
    }
    final manualMemoUids = _effectiveManualMemoUids(existingManualItems);
    if (_type == MemoCollectionType.manual && manualMemoUids.isEmpty) {
      final shouldContinue = await _confirmEmptyManualSave();
      if (!shouldContinue) return;
    }
    final repository = ref.read(collectionsRepositoryProvider);
    final draft = _draftCollection;
    await repository.upsert(draft);
    if (draft.type == MemoCollectionType.manual) {
      await _persistManualItems(
        repository: repository,
        collectionId: draft.id,
        existingManualItems: existingManualItems,
        desiredMemoUids: manualMemoUids,
      );
    } else if (_isEditing &&
        widget.initialCollection?.type == MemoCollectionType.manual) {
      final removedMemoUids = existingManualItems
          .map((item) => item.uid)
          .where((item) => item.trim().isNotEmpty)
          .toList(growable: false);
      if (removedMemoUids.isNotEmpty) {
        await repository.removeManualItem(draft.id, removedMemoUids);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(draft);
  }

  void _setType(MemoCollectionType value) {
    _updateState(() {
      _type = value;
      if (value == MemoCollectionType.manual &&
          _sortMode != CollectionSortMode.manualOrder) {
        _sortMode = CollectionSortMode.manualOrder;
      } else if (value == MemoCollectionType.smart &&
          _sortMode == CollectionSortMode.manualOrder) {
        _sortMode = CollectionSortMode.displayTimeDesc;
      }
    });
  }

  void _markChanged() {
    setState(() => _hasLocalChanges = true);
  }

  void _updateState(VoidCallback update) {
    setState(() {
      update();
      _hasLocalChanges = true;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickTags(List<TagStat> tags) async {
    final mediaQuery = MediaQuery.of(context);
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.78),
      builder: (_) =>
          _CollectionTagPickerSheet(tags: tags, initial: _selectedTags),
    );
    if (selected == null) return;
    _updateState(() {
      _selectedTags
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _pickCustomDateRange() async {
    final initialRange =
        _dateRule.type == CollectionDateRuleType.customRange &&
            _dateRule.startTimeSec != null &&
            _dateRule.endTimeSecExclusive != null
        ? DateTimeRange(
            start: DateTime.fromMillisecondsSinceEpoch(
              _dateRule.startTimeSec! * 1000,
              isUtc: true,
            ).toLocal(),
            end: DateTime.fromMillisecondsSinceEpoch(
              (_dateRule.endTimeSecExclusive! - 1) * 1000,
              isUtc: true,
            ).toLocal(),
          )
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialRange,
    );
    if (picked == null) return;
    _updateState(() {
      final start = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      final endExclusive = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      ).add(const Duration(days: 1));
      _dateRule = CollectionDateRule(
        type: CollectionDateRuleType.customRange,
        startTimeSec: start.toUtc().millisecondsSinceEpoch ~/ 1000,
        endTimeSecExclusive:
            endExclusive.toUtc().millisecondsSinceEpoch ~/ 1000,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.t.strings.collections;
    final tagsAsync = ref.watch(tagStatsProvider);
    final memosAsync = ref.watch(collectionCandidateMemosProvider);
    final tagLookup = ref.watch(tagColorLookupProvider);
    final existingManualItemUidsAsync =
        widget.initialCollection?.type == MemoCollectionType.manual
        ? ref.watch(
            collectionManualItemUidsProvider(widget.initialCollection!.id),
          )
        : const AsyncValue.data(<String>[]);
    final existingManualItems =
        widget.initialCollection?.type == MemoCollectionType.manual
        ? resolveManualCollectionItemsInStoredOrder(
            memosAsync.valueOrNull ?? const <LocalMemo>[],
            existingManualItemUidsAsync.valueOrNull ?? const <String>[],
          )
        : const <LocalMemo>[];
    final previewItems = _buildPreviewItems(
      memos: memosAsync.valueOrNull ?? const <LocalMemo>[],
      tagLookup: tagLookup,
      existingManualItems: existingManualItems,
    );
    final coverAttachmentOptions = _buildCoverAttachmentOptions(previewItems);
    final selectedCoverOptionKey = _selectedCoverOptionKey(
      coverAttachmentOptions,
    );
    final preview = buildCollectionPreview(
      _draftCollection,
      previewItems,
      resolveTagColorHexByPath: tagLookup.resolveEffectiveHexByPath,
    );
    final colors = _CollectionEditorColors.fromTheme(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final allow = await _handleExitGuard();
        if (!mounted || !allow) return;
        navigator.maybePop();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: context.t.strings.legacy.msg_back,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final navigator = Navigator.of(context);
              final allow = await _handleExitGuard();
              if (!mounted || !allow) return;
              navigator.maybePop();
            },
          ),
          title: Text(
            _isEditing
                ? collections.editCollection
                : collections.createCollection,
          ),
        ),
        bottomNavigationBar: _buildBottomBar(
          context: context,
          colors: colors,
          preview: preview,
          existingManualItems: existingManualItems,
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 8, 20, _bottomBarHeight + 96),
          children: [
            _buildBasicsSection(context, colors: colors),
            _buildSectionDivider(colors),
            if (_type == MemoCollectionType.smart)
              _buildSmartSourceSection(
                context,
                colors: colors,
                tagsAsync: tagsAsync,
              )
            else
              _buildManualSourceSection(
                context,
                colors: colors,
                existingManualItems: existingManualItems,
                previewItems: previewItems,
              ),
            if (_isEditing) ...[
              _buildSectionDivider(colors),
              _buildPreviewSection(context, colors: colors, preview: preview),
            ],
            _buildSectionDivider(colors),
            _buildAdvancedSection(
              context,
              colors: colors,
              coverAttachmentOptions: coverAttachmentOptions,
              selectedCoverOptionKey: selectedCoverOptionKey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar({
    required BuildContext context,
    required _CollectionEditorColors colors,
    required MemoCollectionPreview preview,
    required List<LocalMemo> existingManualItems,
  }) {
    final canSave = _canSave(existingManualItems);
    return SafeArea(
      top: false,
      child: MeasureSize(
        onChange: (size) {
          if (!mounted || size.height == _bottomBarHeight) {
            return;
          }
          setState(() {
            _bottomBarHeight = size.height;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            border: Border(top: BorderSide(color: colors.divider)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _footerSummary(context, preview, existingManualItems),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _type == MemoCollectionType.smart
                          ? _smartRuleSummary(context)
                          : context.tr(
                              zh: '从这里直接添加 memo，创建后不用再跳去别处维护。',
                              en: 'Add memos here first, then finish creating in one go.',
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: canSave
                    ? () => _save(existingManualItems: existingManualItems)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: MemoFlowPalette.primary,
                  foregroundColor:
                      ThemeData.estimateBrightnessForColor(
                            MemoFlowPalette.primary,
                          ) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(_submitLabel(context, existingManualItems)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider(_CollectionEditorColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1, color: colors.divider),
    );
  }

  Widget _buildBasicsSection(
    BuildContext context, {
    required _CollectionEditorColors colors,
  }) {
    final collections = context.t.strings.collections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: collections.basics, mutedColor: colors.textMuted),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CollectionTypeCard(
                label: collectionTypeLabel(context, MemoCollectionType.smart),
                description: context.tr(zh: '自动收录', en: 'Auto match'),
                icon: Icons.auto_awesome_rounded,
                selected: _type == MemoCollectionType.smart,
                colors: colors,
                onTap: () => _setType(MemoCollectionType.smart),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CollectionTypeCard(
                label: collectionTypeLabel(context, MemoCollectionType.manual),
                description: context.tr(zh: '手动挑选', en: 'Pick manually'),
                icon: Icons.playlist_add_check_rounded,
                selected: _type == MemoCollectionType.manual,
                colors: colors,
                onTap: () => _setType(MemoCollectionType.manual),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _EditorFieldShell(
          label: context.t.strings.legacy.msg_title,
          colors: colors,
          child: TextField(
            controller: _titleController,
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: context.tr(zh: '给它起个名字', en: 'Give it a name'),
            ),
            onChanged: (_) => _markChanged(),
          ),
        ),
        const SizedBox(height: 10),
        _EditorFieldShell(
          label: collections.description,
          colors: colors,
          child: TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: context.tr(
                zh: '可选：写一句这个合集要收什么',
                en: 'Optional: add a short note',
              ),
            ),
            onChanged: (_) => _markChanged(),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartSourceSection(
    BuildContext context, {
    required _CollectionEditorColors colors,
    required AsyncValue<List<TagStat>> tagsAsync,
  }) {
    final collections = context.t.strings.collections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.tr(zh: '内容来源', en: 'Content source'),
          mutedColor: colors.textMuted,
          trailing: _draftRules.hasAnyConstraint
              ? Text(
                  _smartRuleSummary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PresetChip(
              label: collections.last7Days,
              colors: colors,
              onTap: () => _updateState(() {
                _dateRule = const CollectionDateRule(
                  type: CollectionDateRuleType.lastDays,
                  lastDays: 7,
                );
              }),
            ),
            _PresetChip(
              label: collections.last30Days,
              colors: colors,
              tint: colors.secondaryTint,
              onTap: () => _updateState(() {
                _dateRule = const CollectionDateRule(
                  type: CollectionDateRuleType.lastDays,
                  lastDays: 30,
                );
              }),
            ),
            _PresetChip(
              label: collections.attachmentImagesOnly,
              colors: colors,
              tint: colors.tertiaryTint,
              onTap: () => _updateState(
                () => _attachmentRule = CollectionAttachmentRule.imagesOnly,
              ),
            ),
            _PresetChip(
              label: collections.pinnedOnly,
              colors: colors,
              onTap: () => _updateState(() => _pinnedOnly = true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: tagsAsync.hasValue
                    ? () => _pickTags(tagsAsync.valueOrNull ?? const [])
                    : null,
                icon: const Icon(Icons.sell_rounded),
                label: Text(collections.selectTags),
              ),
            ),
          ],
        ),
        if (tagsAsync.hasError) ...[
          const SizedBox(height: 8),
          Text(
            '${tagsAsync.error}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
          ),
        ],
        if (_selectedTags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _selectedTags.toList()..sort())
                InputChip(
                  label: Text('#$tag'),
                  onDeleted: () =>
                      _updateState(() => _selectedTags.remove(tag)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _ChipGroupField(
          label: collections.dateRange,
          colors: colors,
          children: [
            _buildChoiceChip(
              label: collections.allTime,
              selected: _dateRule.type == CollectionDateRuleType.all,
              colors: colors,
              onSelected: () =>
                  _updateState(() => _dateRule = CollectionDateRule.defaults),
            ),
            _buildChoiceChip(
              label: collections.last7Days,
              selected:
                  _dateRule.type == CollectionDateRuleType.lastDays &&
                  _dateRule.lastDays == 7,
              colors: colors,
              onSelected: () => _updateState(() {
                _dateRule = const CollectionDateRule(
                  type: CollectionDateRuleType.lastDays,
                  lastDays: 7,
                );
              }),
            ),
            _buildChoiceChip(
              label: collections.last30Days,
              selected:
                  _dateRule.type == CollectionDateRuleType.lastDays &&
                  _dateRule.lastDays == 30,
              colors: colors,
              onSelected: () => _updateState(() {
                _dateRule = const CollectionDateRule(
                  type: CollectionDateRuleType.lastDays,
                  lastDays: 30,
                );
              }),
            ),
            _buildChoiceChip(
              label: _dateRule.type == CollectionDateRuleType.customRange
                  ? _customDateRangeLabel(context)
                  : collections.customRange,
              selected: _dateRule.type == CollectionDateRuleType.customRange,
              colors: colors,
              onSelected: _pickCustomDateRange,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ChipGroupField(
          label: context.tr(zh: '内容类型', en: 'Content type'),
          colors: colors,
          children: [
            _buildChoiceChip(
              label: collections.attachmentAny,
              selected: _attachmentRule == CollectionAttachmentRule.any,
              colors: colors,
              onSelected: () => _updateState(
                () => _attachmentRule = CollectionAttachmentRule.any,
              ),
            ),
            _buildChoiceChip(
              label: collections.attachmentRequired,
              selected: _attachmentRule == CollectionAttachmentRule.required,
              colors: colors,
              onSelected: () => _updateState(
                () => _attachmentRule = CollectionAttachmentRule.required,
              ),
            ),
            _buildChoiceChip(
              label: collections.attachmentImagesOnly,
              selected: _attachmentRule == CollectionAttachmentRule.imagesOnly,
              colors: colors,
              onSelected: () => _updateState(
                () => _attachmentRule = CollectionAttachmentRule.imagesOnly,
              ),
            ),
            _buildChoiceChip(
              label: collections.attachmentNone,
              selected: _attachmentRule == CollectionAttachmentRule.excluded,
              colors: colors,
              onSelected: () => _updateState(
                () => _attachmentRule = CollectionAttachmentRule.excluded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(
              context.tr(zh: '更多条件', en: 'More filters'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              context.tr(
                zh: '匹配方式、公开范围、子标签、置顶',
                en: 'Match mode, visibility, descendants, pinned',
              ),
              style: TextStyle(color: colors.textMuted),
            ),
            children: [
              const SizedBox(height: 8),
              _EnumSegment<CollectionTagMatchMode>(
                title: collections.tagMatch,
                values: const [
                  CollectionTagMatchMode.any,
                  CollectionTagMatchMode.all,
                ],
                current: _tagMatchMode,
                labelBuilder: (value) => switch (value) {
                  CollectionTagMatchMode.any => collections.anyTag,
                  CollectionTagMatchMode.all => collections.allTags,
                },
                onChanged: (value) => _updateState(() => _tagMatchMode = value),
              ),
              const SizedBox(height: 12),
              _EnumSegment<CollectionVisibilityScope>(
                title: context.t.strings.legacy.msg_visibility,
                values: const [
                  CollectionVisibilityScope.all,
                  CollectionVisibilityScope.privateOnly,
                  CollectionVisibilityScope.publicOnly,
                ],
                current: _visibility,
                labelBuilder: (value) => switch (value) {
                  CollectionVisibilityScope.all =>
                    context.t.strings.legacy.msg_all,
                  CollectionVisibilityScope.privateOnly =>
                    context.t.strings.legacy.msg_private,
                  CollectionVisibilityScope.publicOnly =>
                    context.t.strings.legacy.msg_public,
                },
                onChanged: (value) => _updateState(() => _visibility = value),
              ),
              SwitchListTile.adaptive(
                value: _includeDescendants,
                contentPadding: EdgeInsets.zero,
                title: Text(collections.includeDescendants),
                subtitle: Text(collections.includeDescendantsDescription),
                onChanged: (value) =>
                    _updateState(() => _includeDescendants = value),
              ),
              SwitchListTile.adaptive(
                value: _pinnedOnly,
                contentPadding: EdgeInsets.zero,
                title: Text(collections.pinnedOnly),
                onChanged: (value) => _updateState(() => _pinnedOnly = value),
              ),
            ],
          ),
        ),
        if (!_draftRules.hasAnyConstraint) ...[
          const SizedBox(height: 8),
          Text(
            collections.ruleRequired,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManualSourceSection(
    BuildContext context, {
    required _CollectionEditorColors colors,
    required List<LocalMemo> existingManualItems,
    required List<LocalMemo> previewItems,
  }) {
    final collections = context.t.strings.collections;
    final selectedMemoUids = _effectiveManualMemoUids(existingManualItems);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.tr(zh: '内容来源', en: 'Content source'),
          mutedColor: colors.textMuted,
          trailing: Text(
            context.tr(
              zh: '已选 ${selectedMemoUids.length} 条',
              en: '${selectedMemoUids.length} selected',
            ),
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _openManualMemoPicker(existingManualItems),
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text(collections.addMemos),
              ),
            ),
            if (previewItems.isNotEmpty) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => _showSelectedMemoSheet(previewItems),
                child: Text(context.t.strings.legacy.msg_preview),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (previewItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: colors.fieldBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              context.tr(
                zh: '还没有添加 memo，先挑几条内容吧。',
                en: 'No memos yet. Pick a few to start this collection.',
              ),
              style: TextStyle(color: colors.textMuted),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.selectedBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < previewItems.take(2).length;
                  index++
                ) ...[
                  _PreviewMemoRow(memo: previewItems[index]),
                  if (index < previewItems.take(2).length - 1)
                    Divider(height: 18, color: colors.divider),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewSection(
    BuildContext context, {
    required _CollectionEditorColors colors,
    required MemoCollectionPreview preview,
  }) {
    final collections = context.t.strings.collections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.tr(zh: '实时预览', en: 'Live preview'),
          mutedColor: colors.textMuted,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.fieldBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PreviewStat(
                    label: collections.previewMemos,
                    value: '${preview.itemCount}',
                  ),
                  const SizedBox(width: 10),
                  _PreviewStat(
                    label: collections.previewImages,
                    value: '${preview.imageItemCount}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                preview.ruleSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 12),
              if (preview.sampleItems.isEmpty)
                Text(
                  _type == MemoCollectionType.smart
                      ? collections.noPreviewSmart
                      : collections.noPreviewManual,
                  style: TextStyle(color: colors.textMuted),
                )
              else
                _PreviewMemoRow(memo: preview.sampleItems.first),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedSection(
    BuildContext context, {
    required _CollectionEditorColors colors,
    required List<_CoverAttachmentOption> coverAttachmentOptions,
    required String? selectedCoverOptionKey,
  }) {
    final collections = context.t.strings.collections;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          context.tr(zh: '个性化与展示设置', en: 'Personalize & display'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        subtitle: Text(
          _displaySummary(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textMuted),
        ),
        children: [
          const SizedBox(height: 12),
          Text(
            context.t.strings.legacy.msg_icon,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final iconKey in kCollectionIconKeys)
                _IconChoice(
                  selected: _iconKey == iconKey,
                  icon: resolveCollectionIcon(iconKey),
                  onTap: () => _updateState(() => _iconKey = iconKey),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            collections.accentColor,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final colorHex in kCollectionAccentPalette)
                _AccentChoice(
                  selected: _accentColorHex == colorHex,
                  colorHex: colorHex,
                  onTap: () => _updateState(() => _accentColorHex = colorHex),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _EnumSegment<CollectionCoverMode>(
            title: collections.cover,
            values: const [
              CollectionCoverMode.auto,
              CollectionCoverMode.attachment,
              CollectionCoverMode.icon,
            ],
            current: _coverMode,
            labelBuilder: (value) => collectionCoverModeLabel(context, value),
            onChanged: (value) {
              _updateState(() {
                _coverMode = value;
                if (value == CollectionCoverMode.attachment &&
                    selectedCoverOptionKey == null &&
                    coverAttachmentOptions.isNotEmpty) {
                  final first = coverAttachmentOptions.first;
                  _coverMemoUid = first.memoUid;
                  _coverAttachmentUid = first.attachment.uid;
                }
              });
            },
          ),
          if (_coverMode == CollectionCoverMode.attachment) ...[
            const SizedBox(height: 12),
            if (coverAttachmentOptions.isEmpty)
              Text(
                collections.noCoverImageAvailable,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              )
            else
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'cover-attachment-${selectedCoverOptionKey ?? 'none'}',
                ),
                initialValue: selectedCoverOptionKey,
                decoration: InputDecoration(labelText: collections.coverImage),
                items: [
                  for (final option in coverAttachmentOptions)
                    DropdownMenuItem(
                      value: option.key,
                      child: Text(option.label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  final option = coverAttachmentOptions.firstWhere(
                    (item) => item.key == value,
                  );
                  _updateState(() {
                    _coverMemoUid = option.memoUid;
                    _coverAttachmentUid = option.attachment.uid;
                  });
                },
              ),
          ],
          const SizedBox(height: 16),
          _EnumSegment<CollectionLayoutMode>(
            title: collections.defaultLayout,
            values: const [
              CollectionLayoutMode.shelf,
              CollectionLayoutMode.timeline,
              CollectionLayoutMode.list,
            ],
            current: _layoutMode,
            labelBuilder: (value) => collectionLayoutLabel(context, value),
            onChanged: (value) => _updateState(() => _layoutMode = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CollectionSectionMode>(
            key: ValueKey<String>('section-${_sectionMode.name}'),
            initialValue: _sectionMode,
            decoration: InputDecoration(labelText: collections.groupBy),
            items: [
              DropdownMenuItem(
                value: CollectionSectionMode.none,
                child: Text(collections.noGroups),
              ),
              DropdownMenuItem(
                value: CollectionSectionMode.month,
                child: Text(collections.month),
              ),
              DropdownMenuItem(
                value: CollectionSectionMode.quarter,
                child: Text(collections.quarter),
              ),
              DropdownMenuItem(
                value: CollectionSectionMode.year,
                child: Text(collections.year),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              _updateState(() => _sectionMode = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CollectionSortMode>(
            key: ValueKey<String>('sort-${_sortMode.name}'),
            initialValue: _sortMode,
            decoration: InputDecoration(
              labelText: context.t.strings.legacy.msg_sort,
            ),
            items: [
              if (_type == MemoCollectionType.manual)
                DropdownMenuItem(
                  value: CollectionSortMode.manualOrder,
                  child: Text(collections.manualOrder),
                ),
              DropdownMenuItem(
                value: CollectionSortMode.displayTimeDesc,
                child: Text(collections.displayTimeDesc),
              ),
              DropdownMenuItem(
                value: CollectionSortMode.displayTimeAsc,
                child: Text(collections.displayTimeAsc),
              ),
              DropdownMenuItem(
                value: CollectionSortMode.updateTimeDesc,
                child: Text(collections.updatedTimeDesc),
              ),
              DropdownMenuItem(
                value: CollectionSortMode.updateTimeAsc,
                child: Text(collections.updatedTimeAsc),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              _updateState(() => _sortMode = value);
            },
          ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            value: _showStats,
            contentPadding: EdgeInsets.zero,
            title: Text(collections.showDetailStats),
            subtitle: Text(collections.showDetailStatsDescription),
            onChanged: (value) => _updateState(() => _showStats = value),
          ),
          SwitchListTile.adaptive(
            value: _hideWhenEmpty,
            contentPadding: EdgeInsets.zero,
            title: Text(collections.hideWhenEmpty),
            subtitle: Text(collections.hideWhenEmptyDescription),
            onChanged: (value) => _updateState(() => _hideWhenEmpty = value),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required _CollectionEditorColors colors,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      selectedColor: colors.selectedBackground,
      backgroundColor: colors.fieldBackground,
      labelStyle: TextStyle(
        color: selected ? colors.textPrimary : colors.textMuted,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  String _smartRuleSummary(BuildContext context) {
    final segments = <String>[];
    if (_selectedTags.isNotEmpty) {
      segments.add(_selectedTags.take(2).map((tag) => '#$tag').join(' · '));
    }
    switch (_dateRule.type) {
      case CollectionDateRuleType.all:
        break;
      case CollectionDateRuleType.lastDays:
        final days = _dateRule.lastDays;
        if (days != null && days > 0) {
          segments.add(context.t.strings.collections.lastDays(days: days));
        }
      case CollectionDateRuleType.customRange:
        segments.add(_customDateRangeLabel(context));
    }
    if (_attachmentRule != CollectionAttachmentRule.any) {
      segments.add(collectionAttachmentRuleLabel(context, _attachmentRule));
    }
    if (_pinnedOnly) {
      segments.add(context.t.strings.collections.pinnedOnly);
    }
    if (segments.isEmpty) {
      return context.tr(zh: '尚未设置条件', en: 'No rules yet');
    }
    return segments.join(' · ');
  }

  String _displaySummary(BuildContext context) {
    var count = 0;
    if (_iconKey != MemoCollection.defaultIconKey) count += 1;
    if (_accentColorHex != null) count += 1;
    if (_coverMode != CollectionCoverMode.auto) count += 1;
    if (_layoutMode != CollectionLayoutMode.shelf) count += 1;
    if (_sectionMode != CollectionSectionMode.none) count += 1;
    final defaultSort = _type == MemoCollectionType.manual
        ? CollectionSortMode.manualOrder
        : CollectionSortMode.displayTimeDesc;
    if (_sortMode != defaultSort) count += 1;
    if (!_showStats) count += 1;
    if (_hideWhenEmpty) count += 1;
    if (count == 0) {
      return context.tr(zh: '可选，不影响创建', en: 'Optional');
    }
    return context.tr(zh: '已设置 $count 项', en: '$count set');
  }

  List<String> _effectiveManualMemoUids(List<LocalMemo> existingManualItems) {
    final source =
        !_isEditing ||
            _hasExplicitManualMemoSelection ||
            _manualMemoUids.isNotEmpty
        ? _manualMemoUids
        : existingManualItems.map((item) => item.uid).toList(growable: false);
    final seen = <String>{};
    return source
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && seen.add(item))
        .toList(growable: false);
  }

  bool _canSave(List<LocalMemo> existingManualItems) {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    if (!hasTitle) return false;
    if (_type == MemoCollectionType.smart) {
      return _draftRules.hasAnyConstraint;
    }
    return true;
  }

  String _submitLabel(
    BuildContext context,
    List<LocalMemo> existingManualItems,
  ) {
    if (_isEditing) {
      return context.tr(zh: '保存修改', en: 'Save changes');
    }
    final manualCount = _effectiveManualMemoUids(existingManualItems).length;
    if (_type == MemoCollectionType.manual && manualCount > 0) {
      return context.tr(
        zh: '创建并加入 $manualCount 条 memo',
        en: manualCount == 1
            ? 'Create and add 1 memo'
            : 'Create and add $manualCount memos',
      );
    }
    return context.t.strings.collections.createCollection;
  }

  String _footerSummary(
    BuildContext context,
    MemoCollectionPreview preview,
    List<LocalMemo> existingManualItems,
  ) {
    if (_type == MemoCollectionType.manual) {
      final count = _effectiveManualMemoUids(existingManualItems).length;
      return context.tr(zh: '已选 $count 条', en: '$count selected');
    }
    return context.tr(
      zh: '已命中 ${preview.itemCount} 条',
      en: '${preview.itemCount} matched',
    );
  }

  Future<void> _openManualMemoPicker(
    List<LocalMemo> existingManualItems,
  ) async {
    final selected = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        fullscreenDialog: true,
        builder: (_) => _ManualMemoPickerScreen(
          initialSelectedMemoUids: _effectiveManualMemoUids(
            existingManualItems,
          ),
        ),
      ),
    );
    if (selected == null) return;
    _updateState(() {
      _hasExplicitManualMemoSelection = true;
      _manualMemoUids
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _showSelectedMemoSheet(List<LocalMemo> previewItems) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = _CollectionEditorColors.fromTheme(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(zh: '已选内容', en: 'Selected memos'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: previewItems.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.divider),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: _PreviewMemoRow(memo: previewItems[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmEmptyManualSave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(zh: '空手动合集', en: 'Empty manual collection')),
        content: Text(
          context.tr(
            zh: '当前还没有添加 memo，仍然保存这个合集吗？',
            en: 'This manual collection has no memos yet. Save it anyway?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t.strings.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.t.strings.legacy.msg_save),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<bool> _handleExitGuard() async {
    if (!_hasLocalChanges) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.tr(zh: '放弃未保存的修改？', en: 'Discard unsaved changes?'),
        ),
        content: Text(
          context.tr(
            zh: '返回后，本页刚才的修改不会保留。',
            en: 'If you leave now, the changes on this screen will be lost.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.t.strings.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr(zh: '放弃', en: 'Discard')),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _persistManualItems({
    required CollectionsRepository repository,
    required String collectionId,
    required List<LocalMemo> existingManualItems,
    required List<String> desiredMemoUids,
  }) async {
    final existingMemoUids = existingManualItems
        .map((item) => item.uid.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final desiredSet = desiredMemoUids.toSet();
    final existingSet = existingMemoUids.toSet();
    final toRemove = existingMemoUids
        .where((item) => !desiredSet.contains(item))
        .toList(growable: false);
    final toAdd = desiredMemoUids
        .where((item) => !existingSet.contains(item))
        .toList(growable: false);
    if (toRemove.isNotEmpty) {
      await repository.removeManualItem(collectionId, toRemove);
    }
    if (toAdd.isNotEmpty) {
      await repository.addManualItems(collectionId, toAdd);
    }
    if (desiredMemoUids.isNotEmpty) {
      await repository.reorderManualItems(collectionId, desiredMemoUids);
    }
  }

  List<LocalMemo> _buildPreviewItems({
    required List<LocalMemo> memos,
    required TagColorLookup tagLookup,
    required List<LocalMemo> existingManualItems,
  }) {
    if (_type == MemoCollectionType.manual) {
      return resolveCollectionItems(
        _draftCollection,
        memos,
        manualMemoUids: _effectiveManualMemoUids(existingManualItems),
        resolveCanonicalTagPath: tagLookup.resolveCanonicalPath,
      );
    }
    return resolveCollectionItems(
      _draftCollection,
      memos,
      resolveCanonicalTagPath: tagLookup.resolveCanonicalPath,
    );
  }

  List<_CoverAttachmentOption> _buildCoverAttachmentOptions(
    List<LocalMemo> items,
  ) {
    final options = <_CoverAttachmentOption>[];
    for (final memo in items) {
      for (final attachment in memo.attachments) {
        if (!attachment.isImage) continue;
        options.add(
          _CoverAttachmentOption(
            memoUid: memo.uid,
            attachment: attachment,
            label:
                '${DateFormat.yMMMd().format(memo.effectiveDisplayTime)} • ${attachment.displayName}',
          ),
        );
      }
      if (options.length >= 24) {
        break;
      }
    }
    return options;
  }

  String? _selectedCoverOptionKey(List<_CoverAttachmentOption> options) {
    final memoUid = _coverMemoUid;
    final attachmentUid = _coverAttachmentUid;
    if (memoUid == null || attachmentUid == null) return null;
    for (final option in options) {
      if (option.memoUid == memoUid && option.attachment.uid == attachmentUid) {
        return option.key;
      }
    }
    return null;
  }

  String _customDateRangeLabel(BuildContext context) {
    final start = _dateRule.startTimeSec;
    final end = _dateRule.endTimeSecExclusive;
    if (start == null || end == null) {
      return context.t.strings.collections.chooseRange;
    }
    final formatter = DateFormat.yMMMd();
    final startDate = DateTime.fromMillisecondsSinceEpoch(
      start * 1000,
      isUtc: true,
    ).toLocal();
    final endDate = DateTime.fromMillisecondsSinceEpoch(
      (end - 1) * 1000,
      isUtc: true,
    ).toLocal();
    return '${formatter.format(startDate)} – ${formatter.format(endDate)}';
  }
}

class _CoverAttachmentOption {
  const _CoverAttachmentOption({
    required this.memoUid,
    required this.attachment,
    required this.label,
  });

  final String memoUid;
  final Attachment attachment;
  final String label;

  String get key => '$memoUid::${attachment.uid}';
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? MemoFlowPalette.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? MemoFlowPalette.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({
    required this.selected,
    required this.colorHex,
    required this.onTap,
  });

  final bool selected;
  final String colorHex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = resolveCollectionAccentColor(colorHex, isDark: false);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            width: selected ? 3 : 1,
            color: selected
                ? Colors.white
                : Colors.black.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }
}

class _EnumSegment<T> extends StatelessWidget {
  const _EnumSegment({
    required this.title,
    required this.values,
    required this.current,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String title;
  final List<T> values;
  final T current;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              ChoiceChip(
                selected: current == value,
                label: Text(labelBuilder(value)),
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _PreviewMemoRow extends StatelessWidget {
  const _PreviewMemoRow({required this.memo});

  final LocalMemo memo;

  @override
  Widget build(BuildContext context) {
    final content = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = content.isEmpty
        ? context.t.strings.legacy.msg_empty_content
        : (content.length > 88 ? '${content.substring(0, 88)}...' : content);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: MemoFlowPalette.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            memo.attachments.any((item) => item.isImage)
                ? Icons.photo_rounded
                : Icons.notes_rounded,
            color: MemoFlowPalette.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.yMMMd().add_Hm().format(memo.effectiveDisplayTime),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CollectionEditorColors {
  const _CollectionEditorColors({
    required this.background,
    required this.fieldBackground,
    required this.selectedBackground,
    required this.divider,
    required this.textPrimary,
    required this.textMuted,
    required this.secondaryTint,
    required this.tertiaryTint,
  });

  final Color background;
  final Color fieldBackground;
  final Color selectedBackground;
  final Color divider;
  final Color textPrimary;
  final Color textMuted;
  final Color secondaryTint;
  final Color tertiaryTint;

  factory _CollectionEditorColors.fromTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textPrimary.withValues(alpha: isDark ? 0.72 : 0.64);
    return _CollectionEditorColors(
      background: isDark
          ? MemoFlowPalette.backgroundDark
          : MemoFlowPalette.backgroundLight,
      fieldBackground: isDark
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.88),
      selectedBackground: MemoFlowPalette.primary.withValues(
        alpha: isDark ? 0.24 : 0.10,
      ),
      divider: isDark
          ? MemoFlowPalette.borderDark
          : MemoFlowPalette.borderLight,
      textPrimary: textPrimary,
      textMuted: textMuted,
      secondaryTint: const Color(0xFFF2E9DC),
      tertiaryTint: const Color(0xFFF8ECE6),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.mutedColor,
    this.trailing,
  });

  final String title;
  final Color mutedColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _CollectionTypeCard extends StatelessWidget {
  const _CollectionTypeCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final _CollectionEditorColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? colors.selectedBackground : colors.fieldBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? MemoFlowPalette.primary : colors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorFieldShell extends StatelessWidget {
  const _EditorFieldShell({
    required this.label,
    required this.colors,
    required this.child,
  });

  final String label;
  final _CollectionEditorColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.fieldBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _ChipGroupField extends StatelessWidget {
  const _ChipGroupField({
    required this.label,
    required this.colors,
    required this.children,
  });

  final String label;
  final _CollectionEditorColors colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.colors,
    required this.onTap,
    this.tint,
  });

  final String label;
  final _CollectionEditorColors colors;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final background = tint ?? colors.selectedBackground;
    return ActionChip(
      onPressed: onTap,
      backgroundColor: background,
      labelStyle: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      label: Text(label),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
    );
  }
}

class _ManualMemoPickerScreen extends ConsumerStatefulWidget {
  const _ManualMemoPickerScreen({required this.initialSelectedMemoUids});

  final List<String> initialSelectedMemoUids;

  @override
  ConsumerState<_ManualMemoPickerScreen> createState() =>
      _ManualMemoPickerScreenState();
}

class _ManualMemoPickerScreenState
    extends ConsumerState<_ManualMemoPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final List<String> _selectedMemoUids = [
    ...widget.initialSelectedMemoUids,
  ];
  bool _onlyImages = false;
  bool _recentOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleMemo(LocalMemo memo) {
    setState(() {
      if (_selectedMemoUids.contains(memo.uid)) {
        _selectedMemoUids.remove(memo.uid);
      } else {
        _selectedMemoUids.add(memo.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.t.strings.collections;
    final colors = _CollectionEditorColors.fromTheme(context);
    final candidatesAsync = ref.watch(collectionCandidateMemosProvider);
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(context.tr(zh: '选择 memo', en: 'Select memos')),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(
                    zh: '已选 ${_selectedMemoUids.length} 条',
                    en: '${_selectedMemoUids.length} selected',
                  ),
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(List<String>.from(_selectedMemoUids)),
                style: FilledButton.styleFrom(
                  backgroundColor: MemoFlowPalette.primary,
                ),
                child: Text(
                  collections.addSelected(count: _selectedMemoUids.length),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _buildSelectedSummary(candidatesAsync.valueOrNull ?? const []),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textMuted),
            ),
            const SizedBox(height: 10),
            _EditorFieldShell(
              label: collections.searchMemos,
              colors: colors,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: collections.searchMemos,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: _onlyImages,
                  label: Text(collections.attachmentImagesOnly),
                  onSelected: (_) => setState(() => _onlyImages = !_onlyImages),
                ),
                ChoiceChip(
                  selected: _recentOnly,
                  label: Text(collections.last30Days),
                  onSelected: (_) => setState(() => _recentOnly = !_recentOnly),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: candidatesAsync.when(
                data: (candidates) {
                  final cutoff = DateTime.now().subtract(
                    const Duration(days: 30),
                  );
                  final filtered = candidates
                      .where((memo) {
                        if (_onlyImages &&
                            !memo.attachments.any((item) => item.isImage)) {
                          return false;
                        }
                        if (_recentOnly &&
                            memo.effectiveDisplayTime.isBefore(cutoff)) {
                          return false;
                        }
                        if (query.isEmpty) return true;
                        if (memo.content.toLowerCase().contains(query)) {
                          return true;
                        }
                        for (final tag in memo.tags) {
                          if (tag.toLowerCase().contains(query)) return true;
                        }
                        return false;
                      })
                      .toList(growable: false);

                  if (filtered.isEmpty) {
                    return CollectionStatusView(
                      icon: Icons.search_off_rounded,
                      title: context.tr(
                        zh: '没有可添加的 memo',
                        en: 'No memos found',
                      ),
                      description: context.tr(
                        zh: '试试换个关键词或放宽筛选条件。',
                        en: 'Try another keyword or relax the filters.',
                      ),
                      centered: false,
                      compact: true,
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.divider),
                    itemBuilder: (context, index) {
                      final memo = filtered[index];
                      final selected = _selectedMemoUids.contains(memo.uid);
                      final content = memo.content
                          .replaceAll(RegExp(r'\s+'), ' ')
                          .trim();
                      final preview = content.isEmpty
                          ? context.t.strings.legacy.msg_empty_content
                          : content;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? MemoFlowPalette.primary
                              : colors.textMuted,
                        ),
                        title: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          memo.tags.take(3).map((tag) => '#$tag').join('  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _toggleMemo(memo),
                      );
                    },
                  );
                },
                error: (error, _) => CollectionErrorView(
                  title: collections.unableToLoadMemos,
                  message: '$error',
                  centered: false,
                  compact: true,
                ),
                loading: () => CollectionLoadingView(
                  label: collections.loadingMemos,
                  centered: false,
                  compact: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSelectedSummary(List<LocalMemo> candidates) {
    if (_selectedMemoUids.isEmpty) {
      return context.tr(zh: '还没有选择内容', en: 'No memos selected yet');
    }
    final selectedSet = _selectedMemoUids.toSet();
    final previews = candidates
        .where((memo) => selectedSet.contains(memo.uid))
        .take(2)
        .map((memo) {
          final content = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
          return content.isEmpty
              ? context.t.strings.legacy.msg_empty_content
              : content;
        })
        .toList(growable: false);
    final suffix = _selectedMemoUids.length > previews.length ? '…' : '';
    return context.tr(
      zh: '已选：${previews.join('、')}$suffix',
      en: 'Selected: ${previews.join(', ')}$suffix',
    );
  }
}

class _CollectionTagPickerSheet extends StatefulWidget {
  const _CollectionTagPickerSheet({required this.tags, required this.initial});

  final List<TagStat> tags;
  final Set<String> initial;

  @override
  State<_CollectionTagPickerSheet> createState() =>
      _CollectionTagPickerSheetState();
}

class _CollectionTagPickerSheetState extends State<_CollectionTagPickerSheet> {
  late final Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: 0.55);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.t.strings.legacy.msg_cancel_2,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                Text(
                  context.t.strings.legacy.msg_select_tags,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: Text(
                    context.t.strings.legacy.msg_done,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: widget.tags.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.t.strings.legacy.msg_no_tags,
                      style: TextStyle(color: textMuted),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.tags.length,
                    itemBuilder: (context, index) {
                      final tag = widget.tags[index];
                      final selected = _selected.contains(tag.tag);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(tag.tag);
                            } else {
                              _selected.remove(tag.tag);
                            }
                          });
                        },
                        title: Text(
                          '#${tag.tag}',
                          style: TextStyle(
                            color: textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${tag.count}',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        activeColor: MemoFlowPalette.primary,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
