import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/models/collection_reader.dart';
import '../../data/models/device_preferences.dart';
import '../../data/models/local_memo.dart';
import '../../data/models/memo_collection.dart';
import '../../i18n/strings.g.dart';
import '../../state/collections/collection_reader_progress_provider.dart';
import '../../state/collections/collections_provider.dart';
import '../../state/memos/memos_list_providers.dart';
import '../../state/settings/device_preferences_provider.dart';
import '../memos/memo_detail_screen.dart';
import 'add_to_collection_sheet.dart';
import 'collection_reader_animation_delegate.dart';
import 'collection_reader_auto_page_sheet.dart';
import 'collection_reader_click_actions_sheet.dart';
import 'collection_editor_screen.dart';
import 'collection_reader_menu_logic.dart';
import 'collection_reader_overlay.dart';
import 'collection_reader_page_engine.dart';
import 'collection_reader_page_models.dart';
import 'collection_reader_paged_view.dart';
import 'collection_reader_padding_sheet.dart';
import 'collection_reader_search_sheet.dart';
import 'collection_reader_style_sheet.dart';
import 'collection_reader_toc_sheet.dart';
import 'collection_reader_tip_sheet.dart';
import 'collection_reader_utils.dart';
import 'collection_reader_vertical_view.dart';
import 'collection_reader_more_settings_sheet.dart';
import 'manual_collection_manage_screen.dart';
import 'reader_background_resolver.dart';
import 'reader_platform_capabilities.dart';

class CollectionReaderShell extends ConsumerStatefulWidget {
  const CollectionReaderShell({
    super.key,
    required this.collectionId,
    required this.collectionTitle,
    required this.items,
  });

  @visibleForTesting
  static Future<void> Function(bool enabled)? debugSetKeepAwakeOverride;

  @visibleForTesting
  static Future<void> Function(SystemUiMode mode)? debugSetSystemUiModeOverride;

  @visibleForTesting
  static void Function(SystemUiOverlayStyle style)?
  debugSetSystemUiOverlayStyleOverride;

  final String collectionId;
  final String collectionTitle;
  final List<LocalMemo> items;

  @override
  ConsumerState<CollectionReaderShell> createState() =>
      _CollectionReaderShellState();
}

class _CollectionReaderShellState extends ConsumerState<CollectionReaderShell>
    with WidgetsBindingObserver {
  static const double _fallbackMemoHeight = 520;
  static const Duration _saveDebounceDelay = Duration(milliseconds: 420);
  static const Duration _verticalAutoPageTick = Duration(milliseconds: 40);

  final ScrollController _verticalController = ScrollController();
  final GlobalKey _verticalViewportKey = GlobalKey(
    debugLabel: 'collectionReaderViewport',
  );
  final Map<int, GlobalKey> _verticalItemKeys = <int, GlobalKey>{};
  final Map<int, double> _memoHeights = <int, double>{};
  final CollectionReaderPageEngine _pageEngine = CollectionReaderPageEngine();

  Timer? _saveDebounce;
  Timer? _autoPageTimer;

  late final CollectionReaderProgressRepository _progressRepository;
  CollectionReaderPreferences _lastKnownPreferences =
      DevicePreferences.defaults.collectionReaderPreferences;
  CollectionReaderProgress? _loadedProgress;
  bool _progressReady = false;
  bool _restoredProgress = false;
  bool _autoPaging = false;
  bool _brightnessApplyQueued = false;
  bool _readerEnvironmentSyncQueued = false;
  bool _platformBrightnessSupported = !kIsWeb;
  CollectionReaderMenuState _menuState = CollectionReaderMenuState.hidden;
  CollectionReaderBrightnessMode? _appliedBrightnessMode;
  double? _appliedBrightnessValue;
  bool? _appliedKeepAwake;
  bool? _appliedHideStatusBar;
  bool? _appliedHideNavigationBar;
  bool? _appliedFollowPageStyleForBars;
  Brightness? _appliedSystemBarBrightness;
  int? _appliedSystemBarColorArgb;

  int _currentMemoIndex = 0;
  int _currentChapterPageIndex = 0;
  String? _currentMemoUid;
  String? _highlightQuery;
  String? _highlightMemoUid;
  int? _highlightMatchCharOffset;
  double? _sliderDragValue;
  Size _viewportSize = Size.zero;
  ReaderPageTurnDirection _turnDirection = ReaderPageTurnDirection.none;
  double _lastKnownListScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _progressRepository = ref.read(collectionReaderProgressRepositoryProvider);
    _lastKnownPreferences =
        ref.read(devicePreferencesProvider).collectionReaderPreferences;
    WidgetsBinding.instance.addObserver(this);
    _verticalController.addListener(_handleVerticalScroll);
    unawaited(_loadProgress());
  }

  @override
  void didUpdateWidget(covariant CollectionReaderShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.items.map((item) => item.uid).toList(growable: false),
      widget.items.map((item) => item.uid).toList(growable: false),
    )) {
      _restoredProgress = false;
      _pageEngine.clear();
      _currentMemoIndex = resolveCollectionReaderRestoreIndex(
        items: widget.items,
        progress: _loadedProgress,
      );
      _currentMemoUid = widget.items.isEmpty
          ? null
          : widget.items[_currentMemoIndex].uid;
      _currentChapterPageIndex = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    _stopAutoPage(persist: false, preferences: _lastKnownPreferences);
    unawaited(
      _persistProgress(
        force: true,
        preferences: _lastKnownPreferences,
        repository: _progressRepository,
      ),
    );
    unawaited(_resetApplicationBrightness());
    unawaited(_resetReaderEnvironment());
    _verticalController
      ..removeListener(_handleVerticalScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _dispatchMenuEvent(CollectionReaderMenuEvent.appBackgrounded);
      _stopAutoPage();
      unawaited(_resetApplicationBrightness());
      unawaited(_resetReaderEnvironment());
      unawaited(_persistProgress(force: true));
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _queueBrightnessSync(
        ref.read(devicePreferencesProvider).collectionReaderPreferences,
      );
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadProgress() async {
    final progress = await _progressRepository.load(widget.collectionId);
    if (!mounted) {
      return;
    }
    setState(() {
      _loadedProgress = progress;
      _progressReady = true;
    });
    if (progress != null) {
      _lastKnownListScrollOffset = progress.listScrollOffset;
    }
  }

  void _handleVerticalScroll() {
    if (!_verticalController.hasClients || widget.items.isEmpty) {
      return;
    }
    _lastKnownListScrollOffset = _verticalController.offset;
    _updateCurrentIndexFromViewport();
    _scheduleProgressSave();
  }

  void _updateCurrentIndexFromViewport() {
    final viewportContext = _verticalViewportKey.currentContext;
    final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) {
      return;
    }
    final viewportRect =
        viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    final anchorY =
        viewportRect.top + math.min(viewportRect.height * 0.34, 220);

    int? bestIndex;
    var bestDistance = double.infinity;
    for (final entry in _verticalItemKeys.entries) {
      final itemBox =
          entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (itemBox == null || !itemBox.hasSize) {
        continue;
      }
      final itemRect = itemBox.localToGlobal(Offset.zero) & itemBox.size;
      if (itemRect.bottom < viewportRect.top ||
          itemRect.top > viewportRect.bottom) {
        continue;
      }
      final distance = (itemRect.top - anchorY).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = entry.key;
      }
    }
    if (bestIndex == null) {
      return;
    }
    _setCurrentMemoIndex(bestIndex);
  }

  void _setCurrentMemoIndex(int index) {
    if (widget.items.isEmpty) {
      return;
    }
    final safeIndex = index.clamp(0, widget.items.length - 1);
    final memoUid = widget.items[safeIndex].uid;
    if (safeIndex == _currentMemoIndex && memoUid == _currentMemoUid) {
      return;
    }
    setState(() {
      _currentMemoIndex = safeIndex;
      _currentMemoUid = memoUid;
      if (_highlightMemoUid != memoUid) {
        _highlightMatchCharOffset = null;
      }
    });
  }

  void _scheduleProgressSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDelay, () {
      unawaited(_persistProgress());
    });
  }

  Future<void> _persistProgress({
    bool force = false,
    CollectionReaderPreferences? preferences,
    CollectionReaderProgressRepository? repository,
  }) async {
    final next = _buildProgressSnapshot(preferences: preferences);
    if (next == null) {
      return;
    }
    final effectiveRepository = repository ?? _progressRepository;
    _loadedProgress = next;
    await effectiveRepository.save(next);
    if (force) {
      return;
    }
  }

  CollectionReaderProgress? _buildProgressSnapshot({
    CollectionReaderPreferences? preferences,
  }) {
    if (!_progressReady || widget.items.isEmpty) {
      return null;
    }
    final effectivePreferences = preferences ?? _lastKnownPreferences;
    final safeIndex = _resolveCurrentMemoIndex(preferences: effectivePreferences);
    final currentMemo = widget.items[safeIndex];
    return CollectionReaderProgress(
      collectionId: widget.collectionId,
      readerMode: effectivePreferences.mode,
      pageAnimation: effectivePreferences.pageAnimation,
      currentMemoUid: currentMemo.uid,
      currentMemoIndex: safeIndex,
      currentChapterPageIndex:
          effectivePreferences.mode == CollectionReaderMode.paged
          ? math.max(0, _currentChapterPageIndex)
          : 0,
      listScrollOffset: _verticalController.hasClients
          ? _verticalController.offset
          : (_lastKnownListScrollOffset > 0
                ? _lastKnownListScrollOffset
                : (_loadedProgress?.listScrollOffset ?? 0)),
      currentMatchCharOffset: _highlightMemoUid == currentMemo.uid
          ? _highlightMatchCharOffset
          : null,
      updatedAt: DateTime.now(),
    );
  }

  int _resolveCurrentMemoIndex({CollectionReaderPreferences? preferences}) {
    if (widget.items.isEmpty) {
      return 0;
    }
    final effectivePreferences = preferences ?? _lastKnownPreferences;
    return resolveCollectionReaderRestoreIndex(
      items: widget.items,
      progress: CollectionReaderProgress(
        collectionId: widget.collectionId,
        readerMode: effectivePreferences.mode,
        pageAnimation: effectivePreferences.pageAnimation,
        currentMemoUid: _currentMemoUid,
        currentMemoIndex: _currentMemoIndex,
        currentChapterPageIndex: _currentChapterPageIndex,
        listScrollOffset: _loadedProgress?.listScrollOffset ?? 0,
        currentMatchCharOffset: _highlightMatchCharOffset,
        updatedAt: _loadedProgress?.updatedAt ?? DateTime.now(),
      ),
    );
  }

  void _dispatchMenuEvent(CollectionReaderMenuEvent event) {
    final transition = reduceCollectionReaderMenuState(_menuState, event);
    if (!mounted) {
      return;
    }
    if (transition.nextState != _menuState) {
      setState(() {
        _menuState = transition.nextState;
      });
    }
  }

  void _toggleOverlay() {
    _dispatchMenuEvent(CollectionReaderMenuEvent.toggleOverlay);
  }

  void _handleOverlayInteraction() {
    _dispatchMenuEvent(CollectionReaderMenuEvent.overlayInteraction);
  }

  void _hideMenusForEvent(CollectionReaderMenuEvent event) {
    _dispatchMenuEvent(event);
  }

  void _queueBrightnessSync(CollectionReaderPreferences preferences) {
    final needsApply =
        _appliedBrightnessMode != preferences.brightnessMode ||
        _appliedBrightnessValue != preferences.brightness ||
        !_platformBrightnessSupported;
    if (_brightnessApplyQueued || !needsApply) {
      return;
    }
    _brightnessApplyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _brightnessApplyQueued = false;
      if (!mounted) {
        return;
      }
      await _applyBrightnessPreference(preferences);
    });
  }

  void _queueReaderEnvironmentSync(
    CollectionReaderPreferences preferences,
    ReaderBackgroundPalette palette,
    Brightness hostBrightness,
  ) {
    final needsKeepAwake =
        _appliedKeepAwake != preferences.displayConfig.keepScreenAwakeInReader;
    final followPageStyle = preferences.displayConfig.followPageStyleForBars;
    final needsSystemBars =
        _appliedHideStatusBar != preferences.displayConfig.hideStatusBar ||
        _appliedHideNavigationBar !=
            preferences.displayConfig.hideNavigationBar;
    final effectiveBrightness = followPageStyle
        ? palette.brightness
        : hostBrightness;
    final effectiveBarColor = followPageStyle
        ? palette.background.withValues(alpha: 1)
        : Colors.transparent;
    final needsSystemBarStyle =
        _appliedFollowPageStyleForBars != followPageStyle ||
        _appliedSystemBarBrightness != effectiveBrightness ||
        _appliedSystemBarColorArgb != effectiveBarColor.toARGB32();
    if (_readerEnvironmentSyncQueued || (!needsKeepAwake && !needsSystemBars)) {
      if (!needsSystemBarStyle) {
        return;
      }
    }
    _readerEnvironmentSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _readerEnvironmentSyncQueued = false;
      if (!mounted) {
        return;
      }
      await _applyReaderEnvironment(
        preferences,
        palette: palette,
        hostBrightness: hostBrightness,
      );
    });
  }

  Future<void> _applyReaderEnvironment(
    CollectionReaderPreferences preferences, {
    required ReaderBackgroundPalette palette,
    required Brightness hostBrightness,
  }) async {
    final keepAwake = preferences.displayConfig.keepScreenAwakeInReader;
    if (_appliedKeepAwake != keepAwake && !_autoPaging) {
      await _setKeepAwakeEnabled(keepAwake);
      _appliedKeepAwake = keepAwake;
    }
    final capabilities = ReaderPlatformCapabilities.current();
    if (!capabilities.canControlSystemBars) {
      _appliedHideStatusBar = preferences.displayConfig.hideStatusBar;
      _appliedHideNavigationBar = preferences.displayConfig.hideNavigationBar;
      _appliedFollowPageStyleForBars =
          preferences.displayConfig.followPageStyleForBars;
      _appliedSystemBarBrightness =
          preferences.displayConfig.followPageStyleForBars
          ? palette.brightness
          : hostBrightness;
      _appliedSystemBarColorArgb =
          (preferences.displayConfig.followPageStyleForBars
                  ? palette.background.withValues(alpha: 1)
                  : Colors.transparent)
              .toARGB32();
      return;
    }
    final hideStatusBar = preferences.displayConfig.hideStatusBar;
    final hideNavigationBar = preferences.displayConfig.hideNavigationBar;
    final followPageStyle = preferences.displayConfig.followPageStyleForBars;
    final effectiveBrightness = followPageStyle
        ? palette.brightness
        : hostBrightness;
    final effectiveBarColor = followPageStyle
        ? palette.background.withValues(alpha: 1)
        : Colors.transparent;
    await _setSystemUiMode(
      (hideStatusBar || hideNavigationBar)
          ? SystemUiMode.immersiveSticky
          : SystemUiMode.edgeToEdge,
    );
    _setSystemUiOverlayStyle(
      _resolveReaderSystemUiOverlayStyle(
        brightness: effectiveBrightness,
        barColor: effectiveBarColor,
        hideNavigationBar: hideNavigationBar,
      ),
    );
    _appliedHideStatusBar = hideStatusBar;
    _appliedHideNavigationBar = hideNavigationBar;
    _appliedFollowPageStyleForBars = followPageStyle;
    _appliedSystemBarBrightness = effectiveBrightness;
    _appliedSystemBarColorArgb = effectiveBarColor.toARGB32();
  }

  Future<void> _applyBrightnessPreference(
    CollectionReaderPreferences preferences,
  ) async {
    if (kIsWeb) {
      if (mounted && _platformBrightnessSupported) {
        setState(() => _platformBrightnessSupported = false);
      } else {
        _platformBrightnessSupported = false;
      }
      _appliedBrightnessMode = preferences.brightnessMode;
      _appliedBrightnessValue = preferences.brightness;
      return;
    }
    try {
      if (preferences.brightnessMode == CollectionReaderBrightnessMode.manual) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(
          preferences.brightness,
        );
      } else {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      }
      _appliedBrightnessMode = preferences.brightnessMode;
      _appliedBrightnessValue = preferences.brightness;
      if (mounted && !_platformBrightnessSupported) {
        setState(() => _platformBrightnessSupported = true);
      } else {
        _platformBrightnessSupported = true;
      }
    } catch (_) {
      _appliedBrightnessMode = preferences.brightnessMode;
      _appliedBrightnessValue = preferences.brightness;
      if (mounted && _platformBrightnessSupported) {
        setState(() => _platformBrightnessSupported = false);
      } else {
        _platformBrightnessSupported = false;
      }
    }
  }

  Future<void> _resetApplicationBrightness() async {
    if (kIsWeb) {
      return;
    }
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }

  Future<void> _resetReaderEnvironment() async {
    try {
      await _setKeepAwakeEnabled(false);
    } catch (_) {}
    final capabilities = ReaderPlatformCapabilities.current();
    if (capabilities.canControlSystemBars) {
      try {
        await _setSystemUiMode(SystemUiMode.edgeToEdge);
      } catch (_) {}
    }
    _appliedKeepAwake = false;
    _appliedHideStatusBar = false;
    _appliedHideNavigationBar = false;
    _appliedFollowPageStyleForBars = null;
    _appliedSystemBarBrightness = null;
    _appliedSystemBarColorArgb = null;
  }

  SystemUiOverlayStyle _resolveReaderSystemUiOverlayStyle({
    required Brightness brightness,
    required Color barColor,
    required bool hideNavigationBar,
  }) {
    final iconBrightness = brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: brightness,
      systemNavigationBarColor: hideNavigationBar
          ? Colors.transparent
          : barColor,
      systemNavigationBarDividerColor: hideNavigationBar
          ? Colors.transparent
          : barColor.withValues(alpha: 0.94),
      systemNavigationBarIconBrightness: iconBrightness,
    );
  }

  Future<void> _setKeepAwakeEnabled(bool enabled) async {
    final override = CollectionReaderShell.debugSetKeepAwakeOverride;
    if (override != null) {
      await override(enabled);
      return;
    }
    if (enabled) {
      await WakelockPlus.enable();
      return;
    }
    await WakelockPlus.disable();
  }

  Future<void> _setSystemUiMode(SystemUiMode mode) async {
    final override = CollectionReaderShell.debugSetSystemUiModeOverride;
    if (override != null) {
      await override(mode);
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(mode);
  }

  void _setSystemUiOverlayStyle(SystemUiOverlayStyle style) {
    final override =
        CollectionReaderShell.debugSetSystemUiOverlayStyleOverride;
    if (override != null) {
      override(style);
      return;
    }
    SystemChrome.setSystemUIOverlayStyle(style);
  }

  Future<void> _restoreProgressIfNeeded(
    CollectionReaderPreferences preferences,
  ) async {
    if (_restoredProgress || !_progressReady || widget.items.isEmpty) {
      return;
    }
    _restoredProgress = true;
    final normalized = normalizeCollectionReaderProgress(
      collectionId: widget.collectionId,
      items: widget.items,
      fallbackPreferences: preferences,
      progress: _loadedProgress,
    );
    final memoIndex = normalized.currentMemoIndex.clamp(
      0,
      widget.items.length - 1,
    );
    var pageIndex = normalized.currentChapterPageIndex;
    if (preferences.mode == CollectionReaderMode.paged &&
        _viewportSize.width > 0 &&
        _viewportSize.height > 0) {
      final chapter = _pageEngine.layoutChapter(
        memo: widget.items[memoIndex],
        memoIndex: memoIndex,
        viewportSize: _viewportSize,
        preferences: preferences,
        collectionTitle: widget.collectionTitle,
      );
      pageIndex = _pageEngine.resolveRestoredChapterPageIndex(
        chapter: chapter,
        storedChapterPageIndex: pageIndex,
        matchCharOffset: normalized.currentMatchCharOffset,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _currentMemoIndex = memoIndex;
      _currentMemoUid = normalized.currentMemoUid;
      _currentChapterPageIndex = pageIndex;
      _highlightMatchCharOffset = normalized.currentMatchCharOffset;
      _turnDirection = ReaderPageTurnDirection.none;
    });
    if (preferences.mode == CollectionReaderMode.vertical) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (normalized.listScrollOffset > 0 && _verticalController.hasClients) {
          final maxExtent = _verticalController.position.maxScrollExtent;
          final restoredOffset = normalized.listScrollOffset.clamp(
            0.0,
            maxExtent,
          );
          _verticalController.jumpTo(restoredOffset);
          _lastKnownListScrollOffset = restoredOffset;
          return;
        }
        unawaited(_jumpVerticalToIndex(memoIndex, animate: false));
      });
    }
  }

  Future<void> _jumpVerticalToIndex(int index, {bool animate = true}) async {
    if (widget.items.isEmpty) {
      return;
    }
    final safeIndex = index.clamp(0, widget.items.length - 1);
    final key = _verticalItemKeys[safeIndex];
    final currentContext = key?.currentContext;
    if (currentContext != null) {
      await Scrollable.ensureVisible(
        currentContext,
        duration: animate ? const Duration(milliseconds: 220) : Duration.zero,
        alignment: 0.04,
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (!_verticalController.hasClients) {
      return;
    }
    final maxExtent = _verticalController.position.maxScrollExtent;
    final targetOffset = _estimateScrollOffsetForIndex(
      safeIndex,
    ).clamp(0.0, maxExtent).toDouble();
    if (animate) {
      await _verticalController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _verticalController.jumpTo(targetOffset);
    }
  }

  double _estimateScrollOffsetForIndex(int index) {
    if (index <= 0) {
      return 0;
    }
    final measuredValues = _memoHeights.values;
    final averageHeight = measuredValues.isEmpty
        ? _fallbackMemoHeight
        : measuredValues.reduce((a, b) => a + b) / measuredValues.length;
    var total = 0.0;
    for (var i = 0; i < index; i += 1) {
      total += _memoHeights[i] ?? averageHeight;
    }
    return math.max(0, total - 32);
  }

  void _applyReaderMode(CollectionReaderMode mode) {
    if (ref.read(devicePreferencesProvider).collectionReaderPreferences.mode ==
        mode) {
      return;
    }
    _stopAutoPage();
    ref.read(devicePreferencesProvider.notifier).setCollectionReaderMode(mode);
    if (mode == CollectionReaderMode.vertical) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_jumpVerticalToIndex(_currentMemoIndex, animate: false));
      });
    } else {
      setState(() {
        _currentChapterPageIndex = 0;
        _turnDirection = ReaderPageTurnDirection.none;
      });
    }
    _scheduleProgressSave();
  }

  void _updatePageAnimation(CollectionReaderPageAnimation animation) {
    _pageEngine.clear();
    ref
        .read(devicePreferencesProvider.notifier)
        .setCollectionReaderPageAnimation(animation);
    _scheduleProgressSave();
  }

  Future<void> _showSearchSheet(CollectionReaderPreferences preferences) async {
    _stopAutoPage();
    _dispatchMenuEvent(CollectionReaderMenuEvent.openSearchSheet);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: CollectionReaderSearchSheet(
            items: widget.items,
            onSelect: (result, query) async {
              await _handleSearchSelection(result, query, preferences);
            },
          ),
        );
      },
    );
    if (mounted) {
      _dispatchMenuEvent(CollectionReaderMenuEvent.closeSheet);
    }
  }

  Future<void> _handleSearchSelection(
    CollectionReaderSearchResult result,
    String query,
    CollectionReaderPreferences preferences,
  ) async {
    setState(() {
      _highlightQuery = query;
      _highlightMemoUid = result.memoUid;
      _highlightMatchCharOffset = result.firstMatchOffset;
    });
    if (preferences.mode == CollectionReaderMode.paged &&
        _viewportSize.width > 0 &&
        _viewportSize.height > 0) {
      final chapter = _pageEngine.layoutChapter(
        memo: widget.items[result.memoIndex],
        memoIndex: result.memoIndex,
        viewportSize: _viewportSize,
        preferences: preferences,
        collectionTitle: widget.collectionTitle,
      );
      final pageIndex = _pageEngine.resolveChapterPageIndexForOffset(
        chapter,
        result.firstMatchOffset,
      );
      await _jumpToChapterPage(
        memoIndex: result.memoIndex,
        chapterPageIndex: pageIndex,
        hideEvent: CollectionReaderMenuEvent.searchResultJumped,
        direction: _resolveDirectionForTarget(
          result.memoIndex,
          chapterPageIndex: pageIndex,
          preferences: preferences,
        ),
      );
    } else {
      _setCurrentMemoIndex(result.memoIndex);
      await _jumpVerticalToIndex(result.memoIndex);
    }
    _hideMenusForEvent(CollectionReaderMenuEvent.searchResultJumped);
    _scheduleProgressSave();
  }

  Future<void> _showTocSheet() async {
    _stopAutoPage();
    _dispatchMenuEvent(CollectionReaderMenuEvent.openTocSheet);
    final entries = buildCollectionReaderTocEntries(widget.items);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: CollectionReaderTocSheet(
            entries: entries,
            currentIndex: _currentMemoIndex,
            onSelect: (entry) async {
              await _jumpToChapterPage(
                memoIndex: entry.memoIndex,
                chapterPageIndex: 0,
                hideEvent: CollectionReaderMenuEvent.chapterJumped,
                direction: _resolveDirectionForTarget(
                  entry.memoIndex,
                  chapterPageIndex: 0,
                  preferences: ref
                      .read(devicePreferencesProvider)
                      .collectionReaderPreferences,
                ),
              );
            },
          ),
        );
      },
    );
    if (mounted) {
      _dispatchMenuEvent(CollectionReaderMenuEvent.closeSheet);
    }
  }

  Future<void> _showStyleSheet(CollectionReaderPreferences preferences) async {
    _stopAutoPage();
    _dispatchMenuEvent(CollectionReaderMenuEvent.openSettingsSheet);
    final notifier = ref.read(devicePreferencesProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: CollectionReaderStyleSheet(
            preferences: preferences,
            onThemePresetChanged: notifier.setCollectionReaderThemePreset,
            onBackgroundConfigChanged:
                notifier.setCollectionReaderBackgroundConfig,
            onBrightnessModeChanged: notifier.setCollectionReaderBrightnessMode,
            onBrightnessChanged: notifier.setCollectionReaderBrightness,
            onPageAnimationChanged: notifier.setCollectionReaderPageAnimation,
            onTextScaleChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderTextScale(value);
            },
            onLineSpacingChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderLineSpacing(value);
            },
            onFontFamilyChanged: notifier.setCollectionReaderFontFamily,
            onFontWeightModeChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderFontWeightMode(value);
            },
            onLetterSpacingChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderLetterSpacing(value);
            },
            onParagraphSpacingChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderParagraphSpacing(value);
            },
            onParagraphIndentCharsChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderParagraphIndentChars(value);
            },
            onSavedStyleCardsChanged:
                notifier.setCollectionReaderSavedStyleCards,
            onOpenTipSettings: () {
              Navigator.of(sheetContext).pop();
              unawaited(
                Future<void>.microtask(
                  () => _showTipSheet(
                    ref
                        .read(devicePreferencesProvider)
                        .collectionReaderPreferences,
                  ),
                ),
              );
            },
            onOpenPaddingSettings: () {
              Navigator.of(sheetContext).pop();
              unawaited(
                Future<void>.microtask(
                  () => _showPaddingSheet(
                    ref
                        .read(devicePreferencesProvider)
                        .collectionReaderPreferences,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    if (mounted) {
      _dispatchMenuEvent(CollectionReaderMenuEvent.closeSheet);
      _scheduleProgressSave();
    }
  }

  Future<void> _showTipSheet(CollectionReaderPreferences preferences) async {
    _stopAutoPage();
    _dispatchMenuEvent(CollectionReaderMenuEvent.openSettingsSheet);
    final notifier = ref.read(devicePreferencesProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: CollectionReaderTipSheet(
            preferences: preferences,
            onTitleModeChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderTitleMode(value);
            },
            onTitleScaleChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderTitleScale(value);
            },
            onTitleTopSpacingChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderTitleTopSpacing(value);
            },
            onTitleBottomSpacingChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderTitleBottomSpacing(value);
            },
            onTipLayoutChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderTipLayout(value);
            },
          ),
        );
      },
    );
    if (mounted) {
      _dispatchMenuEvent(CollectionReaderMenuEvent.closeSheet);
      _scheduleProgressSave();
    }
  }

  Future<void> _showPaddingSheet(
    CollectionReaderPreferences preferences,
  ) async {
    _stopAutoPage();
    _dispatchMenuEvent(CollectionReaderMenuEvent.openSettingsSheet);
    final notifier = ref.read(devicePreferencesProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: CollectionReaderPaddingSheet(
            preferences: preferences,
            onPagePaddingChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderPagePadding(value);
            },
            onHeaderPaddingChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderHeaderPadding(value);
            },
            onFooterPaddingChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderFooterPadding(value);
            },
            onShowHeaderLineChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderShowHeaderLine(value);
            },
            onShowFooterLineChanged: (value) {
              _pageEngine.clear();
              notifier.setCollectionReaderShowFooterLine(value);
            },
          ),
        );
      },
    );
    if (mounted) {
      _dispatchMenuEvent(CollectionReaderMenuEvent.closeSheet);
      _scheduleProgressSave();
    }
  }

  Future<void> _showMoreSettingsSheet(
    CollectionReaderPreferences preferences,
  ) async {
    _stopAutoPage();
    _dispatchMenuEvent(CollectionReaderMenuEvent.openSettingsSheet);
    final notifier = ref.read(devicePreferencesProvider.notifier);
    final capabilities = ReaderPlatformCapabilities.current();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: CollectionReaderMoreSettingsSheet(
            displayConfig: preferences.displayConfig,
            inputConfig: preferences.inputConfig,
            capabilities: capabilities,
            onDisplayConfigChanged: notifier.setCollectionReaderDisplayConfig,
            onInputConfigChanged: notifier.setCollectionReaderInputConfig,
            onOpenClickActions: () {
              Navigator.of(sheetContext).pop();
              unawaited(
                Future<void>.microtask(
                  () => _showClickActionsSheet(
                    ref
                        .read(devicePreferencesProvider)
                        .collectionReaderPreferences
                        .tapRegionConfig,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    if (mounted) {
      _dispatchMenuEvent(CollectionReaderMenuEvent.closeSheet);
      _scheduleProgressSave();
    }
  }

  Future<void> _showClickActionsSheet(
    CollectionReaderTapRegionConfig config,
  ) async {
    _stopAutoPage();
    _dispatchMenuEvent(CollectionReaderMenuEvent.openSettingsSheet);
    final notifier = ref.read(devicePreferencesProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return CollectionReaderClickActionsSheet(
          config: config,
          onChanged: notifier.setCollectionReaderTapRegionConfig,
        );
      },
    );
    if (mounted) {
      _dispatchMenuEvent(CollectionReaderMenuEvent.closeSheet);
      _scheduleProgressSave();
    }
  }

  Future<void> _showAutoPageSheet(
    CollectionReaderPreferences preferences,
  ) async {
    _dispatchMenuEvent(CollectionReaderMenuEvent.openAutoPageSheet);
    final notifier = ref.read(devicePreferencesProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return CollectionReaderAutoPageSheet(
          isRunning: _autoPaging,
          secondsPerPage: preferences.autoPageSeconds,
          onToggle: (running) {
            if (running) {
              _startAutoPage();
            } else {
              _stopAutoPage();
            }
          },
          onSecondsChanged: notifier.setCollectionReaderAutoPageSeconds,
        );
      },
    );
    if (mounted) {
      _dispatchMenuEvent(CollectionReaderMenuEvent.closeSheet);
    }
  }

  Future<void> _startAutoPage() async {
    if (_autoPaging) {
      return;
    }
    await WakelockPlus.enable();
    _appliedKeepAwake = true;
    if (!mounted) {
      return;
    }
    setState(() => _autoPaging = true);
    _dispatchMenuEvent(CollectionReaderMenuEvent.autoPageStarted);
    _scheduleAutoPageTick();
  }

  void _scheduleAutoPageTick() {
    _autoPageTimer?.cancel();
    final preferences = ref
        .read(devicePreferencesProvider)
        .collectionReaderPreferences;
    if (!_autoPaging) {
      return;
    }
    if (preferences.mode == CollectionReaderMode.paged) {
      _autoPageTimer = Timer(
        Duration(seconds: preferences.autoPageSeconds),
        () {
          if (!_autoPaging || !mounted) {
            return;
          }
          if (!_goToAdjacentPage(1)) {
            _stopAutoPage();
            return;
          }
          _scheduleAutoPageTick();
        },
      );
      return;
    }
    _autoPageTimer = Timer.periodic(_verticalAutoPageTick, (timer) {
      if (!_autoPaging || !_verticalController.hasClients || !mounted) {
        return;
      }
      final viewportHeight = _viewportSize.height <= 0
          ? 640
          : _viewportSize.height;
      final totalMs = preferences.autoPageSeconds * 1000;
      final step =
          viewportHeight / (totalMs / _verticalAutoPageTick.inMilliseconds);
      final position = _verticalController.position;
      final nextOffset = position.pixels + step;
      if (nextOffset >= position.maxScrollExtent) {
        _verticalController.jumpTo(position.maxScrollExtent);
        _stopAutoPage();
        return;
      }
      _verticalController.jumpTo(nextOffset);
    });
  }

  void _stopAutoPage({
    bool persist = true,
    CollectionReaderPreferences? preferences,
  }) {
    _autoPageTimer?.cancel();
    _autoPageTimer = null;
    if (!_autoPaging) {
      return;
    }
    _autoPaging = false;
    final keepAwake =
        (preferences ?? _lastKnownPreferences).displayConfig.keepScreenAwakeInReader;
    if (keepAwake) {
      _appliedKeepAwake = true;
    } else {
      _appliedKeepAwake = false;
      unawaited(WakelockPlus.disable());
    }
    if (mounted) {
      setState(() {});
    }
    if (persist) {
      _scheduleProgressSave();
    }
  }

  Future<void> _handleMoreAction(
    CollectionReaderMoreAction action,
    MemoCollection? collection,
    LocalMemo? currentMemo,
  ) async {
    _hideMenusForEvent(CollectionReaderMenuEvent.closeSheet);
    switch (action) {
      case CollectionReaderMoreAction.editCollection:
        if (collection == null || !mounted) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CollectionEditorScreen(initialCollection: collection),
          ),
        );
        return;
      case CollectionReaderMoreAction.manageCollectionItems:
        if (!mounted) {
          return;
        }
        if (collection?.isManual == true) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ManualCollectionManageScreen(
                collectionId: widget.collectionId,
              ),
            ),
          );
          return;
        }
        if (collection == null) {
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CollectionEditorScreen(initialCollection: collection),
          ),
        );
        return;
      case CollectionReaderMoreAction.currentMemoActions:
        if (currentMemo == null) {
          return;
        }
        await _showCurrentMemoActions(currentMemo);
        return;
    }
  }

  Future<void> _showCurrentMemoActions(LocalMemo memo) async {
    final collectionsStrings = context.t.strings.collections;
    final legacy = context.t.strings.legacy;
    final action = await showModalBottomSheet<_CurrentMemoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t.strings.collections.reader.currentMemoActions,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  buildCollectionReaderTocTitle(memo, _currentMemoIndex),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: Text(legacy.msg_open_memo),
                  onTap: () =>
                      Navigator.of(context).pop(_CurrentMemoAction.open),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.copy_rounded),
                  title: Text(legacy.msg_copy),
                  onTap: () =>
                      Navigator.of(context).pop(_CurrentMemoAction.copy),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: Text(collectionsStrings.addToCollection),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_CurrentMemoAction.addToCollection),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    memo.pinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                  ),
                  title: Text(memo.pinned ? legacy.msg_unpin : legacy.msg_pin),
                  onTap: () =>
                      Navigator.of(context).pop(_CurrentMemoAction.togglePin),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _CurrentMemoAction.open:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MemoDetailScreen(initialMemo: memo),
          ),
        );
        return;
      case _CurrentMemoAction.copy:
        await Clipboard.setData(ClipboardData(text: memo.content));
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.t.strings.legacy.msg_copied_clipboard),
            ),
          );
        return;
      case _CurrentMemoAction.addToCollection:
        await showAddMemoToCollectionSheet(
          context: context,
          ref: ref,
          memo: memo,
        );
        return;
      case _CurrentMemoAction.togglePin:
        await ref
            .read(memosListControllerProvider)
            .updateMemo(memo, pinned: !memo.pinned);
        return;
    }
  }

  Set<int> _resolveRetainedPagedChapterIndexes({
    Iterable<int> anchorIndexes = const <int>[],
  }) {
    final retained = <int>{};

    void addAnchor(int index) {
      if (index < 0 || index >= widget.items.length) {
        return;
      }
      retained.add(index);
      if (index > 0) {
        retained.add(index - 1);
      }
      if (index + 1 < widget.items.length) {
        retained.add(index + 1);
      }
    }

    addAnchor(_currentMemoIndex);
    for (final index in anchorIndexes) {
      addAnchor(index);
    }
    return retained;
  }

  CollectionReaderPageMap _buildPagedPageMap(
    CollectionReaderPreferences preferences, {
    Iterable<int> anchorIndexes = const <int>[],
  }) {
    return _pageEngine.buildPageMap(
      items: widget.items,
      viewportSize: _viewportSize,
      preferences: preferences,
      collectionTitle: widget.collectionTitle,
      retainMemoIndexes: _resolveRetainedPagedChapterIndexes(
        anchorIndexes: anchorIndexes,
      ),
    );
  }

  void _retainPagedChapterLayouts({
    Iterable<int> anchorIndexes = const <int>[],
  }) {
    if (widget.items.isEmpty) {
      _pageEngine.retainChapterLayoutsForMemoUids(const <String>{});
      return;
    }
    final memoUids = _resolveRetainedPagedChapterIndexes(
      anchorIndexes: anchorIndexes,
    ).map((index) => widget.items[index].uid).toSet();
    _pageEngine.retainChapterLayoutsForMemoUids(memoUids);
  }

  ReaderPage? _resolveAdjacentPage({
    required ReaderChapterLayout? currentChapter,
    required int currentMemoIndex,
    required int currentChapterPageIndex,
    required int delta,
    required CollectionReaderPreferences preferences,
  }) {
    if (currentChapter == null || currentChapter.pages.isEmpty || delta == 0) {
      return null;
    }
    if (delta < 0) {
      final previousIndex = currentChapterPageIndex - 1;
      if (previousIndex >= 0 && previousIndex < currentChapter.pages.length) {
        return currentChapter.pages[previousIndex];
      }
      if (currentMemoIndex <= 0) {
        return null;
      }
      final previousChapter = _pageEngine.layoutChapter(
        memo: widget.items[currentMemoIndex - 1],
        memoIndex: currentMemoIndex - 1,
        viewportSize: _viewportSize,
        preferences: preferences,
        collectionTitle: widget.collectionTitle,
      );
      if (previousChapter.pages.isEmpty) {
        return null;
      }
      return previousChapter.pages.last;
    }
    final nextIndex = currentChapterPageIndex + 1;
    if (nextIndex >= 0 && nextIndex < currentChapter.pages.length) {
      return currentChapter.pages[nextIndex];
    }
    if (currentMemoIndex + 1 >= widget.items.length) {
      return null;
    }
    final nextChapter = _pageEngine.layoutChapter(
      memo: widget.items[currentMemoIndex + 1],
      memoIndex: currentMemoIndex + 1,
      viewportSize: _viewportSize,
      preferences: preferences,
      collectionTitle: widget.collectionTitle,
    );
    if (nextChapter.pages.isEmpty) {
      return null;
    }
    return nextChapter.pages.first;
  }

  bool _goToAdjacentPage(int delta) {
    final preferences = ref
        .read(devicePreferencesProvider)
        .collectionReaderPreferences;
    if (_viewportSize.width <= 0 ||
        _viewportSize.height <= 0 ||
        preferences.mode != CollectionReaderMode.paged) {
      return false;
    }
    if (widget.items.isEmpty) {
      return false;
    }
    final safeMemoIndex = _currentMemoIndex
        .clamp(0, math.max(0, widget.items.length - 1))
        .toInt();
    final currentChapter = _pageEngine.layoutChapter(
      memo: widget.items[safeMemoIndex],
      memoIndex: safeMemoIndex,
      viewportSize: _viewportSize,
      preferences: preferences,
      collectionTitle: widget.collectionTitle,
    );
    if (currentChapter.pages.isEmpty) {
      return false;
    }
    final safePageIndex = _currentChapterPageIndex
        .clamp(0, math.max(0, currentChapter.pages.length - 1))
        .toInt();
    var targetMemoIndex = safeMemoIndex;
    var targetChapterPageIndex = safePageIndex + delta;
    if (delta < 0 && targetChapterPageIndex < 0) {
      if (safeMemoIndex <= 0) {
        return false;
      }
      targetMemoIndex = safeMemoIndex - 1;
      final previousChapter = _pageEngine.layoutChapter(
        memo: widget.items[targetMemoIndex],
        memoIndex: targetMemoIndex,
        viewportSize: _viewportSize,
        preferences: preferences,
        collectionTitle: widget.collectionTitle,
      );
      if (previousChapter.pages.isEmpty) {
        return false;
      }
      targetChapterPageIndex = previousChapter.pages.length - 1;
    } else if (delta > 0 &&
        targetChapterPageIndex >= currentChapter.pages.length) {
      if (safeMemoIndex + 1 >= widget.items.length) {
        return false;
      }
      targetMemoIndex = safeMemoIndex + 1;
      final nextChapter = _pageEngine.layoutChapter(
        memo: widget.items[targetMemoIndex],
        memoIndex: targetMemoIndex,
        viewportSize: _viewportSize,
        preferences: preferences,
        collectionTitle: widget.collectionTitle,
      );
      if (nextChapter.pages.isEmpty) {
        return false;
      }
      targetChapterPageIndex = 0;
    }
    unawaited(
      _jumpToChapterPage(
        memoIndex: targetMemoIndex,
        chapterPageIndex: targetChapterPageIndex,
        hideEvent: CollectionReaderMenuEvent.pageTurned,
        direction: delta < 0
            ? ReaderPageTurnDirection.previous
            : ReaderPageTurnDirection.next,
      ),
    );
    return true;
  }

  Future<void> _jumpToChapterPage({
    required int memoIndex,
    required int chapterPageIndex,
    required ReaderPageTurnDirection direction,
    CollectionReaderMenuEvent hideEvent =
        CollectionReaderMenuEvent.chapterJumped,
  }) async {
    if (widget.items.isEmpty) {
      return;
    }
    final preferences = ref
        .read(devicePreferencesProvider)
        .collectionReaderPreferences;
    if (preferences.mode == CollectionReaderMode.vertical) {
      _setCurrentMemoIndex(memoIndex);
      await _jumpVerticalToIndex(memoIndex);
      _hideMenusForEvent(hideEvent);
      _scheduleProgressSave();
      return;
    }
    final safeMemoIndex = memoIndex.clamp(
      0,
      math.max(0, widget.items.length - 1),
    );
    final chapter = _pageEngine.layoutChapter(
      memo: widget.items[safeMemoIndex.toInt()],
      memoIndex: safeMemoIndex.toInt(),
      viewportSize: _viewportSize,
      preferences: preferences,
      collectionTitle: widget.collectionTitle,
    );
    final safePage = chapterPageIndex
        .clamp(0, math.max(0, chapter.pages.length - 1))
        .toInt();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentMemoIndex = chapter.memoIndex;
      _currentMemoUid = chapter.memo.uid;
      _currentChapterPageIndex = safePage;
      _turnDirection = direction;
    });
    _hideMenusForEvent(hideEvent);
    _scheduleProgressSave();
  }

  ReaderPageTurnDirection _resolveDirectionForTarget(
    int targetMemoIndex, {
    required int chapterPageIndex,
    required CollectionReaderPreferences preferences,
  }) {
    if (preferences.mode != CollectionReaderMode.paged) {
      return ReaderPageTurnDirection.none;
    }
    if (targetMemoIndex < _currentMemoIndex) {
      return ReaderPageTurnDirection.previous;
    }
    if (targetMemoIndex > _currentMemoIndex) {
      return ReaderPageTurnDirection.next;
    }
    if (chapterPageIndex < _currentChapterPageIndex) {
      return ReaderPageTurnDirection.previous;
    }
    if (chapterPageIndex > _currentChapterPageIndex) {
      return ReaderPageTurnDirection.next;
    }
    return ReaderPageTurnDirection.none;
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(
      devicePreferencesProvider.select(
        (prefs) => prefs.collectionReaderPreferences,
      ),
    );
    _lastKnownPreferences = preferences;
    final currentCollection = ref
        .watch(collectionByIdProvider(widget.collectionId))
        .valueOrNull;
    final preferencesNotifier = ref.read(devicePreferencesProvider.notifier);
    _queueBrightnessSync(preferences);
    final readerBody = LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final palette = resolveReaderBackgroundPalette(preferences);
        final baseTheme = Theme.of(context);
        _queueReaderEnvironmentSync(preferences, palette, baseTheme.brightness);
        final readerTheme = baseTheme.copyWith(
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: palette.accent,
                brightness: palette.brightness,
              ).copyWith(
                surface: palette.background,
                onSurface: palette.foreground,
                primary: palette.accent,
                onPrimary: palette.background,
              ),
          scaffoldBackgroundColor: palette.background,
          dividerColor: palette.foreground.withValues(alpha: 0.12),
          textTheme: baseTheme.textTheme.apply(
            bodyColor: palette.foreground,
            displayColor: palette.foreground,
          ),
        );
        final pagedModeReady =
            preferences.mode == CollectionReaderMode.paged &&
            _viewportSize.width > 0 &&
            _viewportSize.height > 0;
        final pageMapNeeded =
            pagedModeReady &&
            (_menuState == CollectionReaderMenuState.overlayVisible ||
                _sliderDragValue != null);
        final pageMap = pageMapNeeded ? _buildPagedPageMap(preferences) : null;
        if (_progressReady && !_restoredProgress) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_restoreProgressIfNeeded(preferences));
          });
        }
        final safeCurrentMemoIndex = _currentMemoIndex
            .clamp(0, math.max(0, widget.items.length - 1))
            .toInt();
        final currentMemo = widget.items.isEmpty
            ? null
            : widget.items[safeCurrentMemoIndex];
        final currentChapter = !pagedModeReady || widget.items.isEmpty
            ? null
            : _pageEngine.layoutChapter(
                memo: widget.items[safeCurrentMemoIndex],
                memoIndex: safeCurrentMemoIndex,
                viewportSize: _viewportSize,
                preferences: preferences,
                collectionTitle: widget.collectionTitle,
              );
        final safeChapterPageIndex = currentChapter == null
            ? 0
            : _currentChapterPageIndex
                  .clamp(0, math.max(0, currentChapter.pages.length - 1))
                  .toInt();
        if (safeChapterPageIndex != _currentChapterPageIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() => _currentChapterPageIndex = safeChapterPageIndex);
          });
        }
        final currentGlobalPageIndex = pageMap == null
            ? safeChapterPageIndex
            : _pageEngine.resolveGlobalPageIndexForMap(
                pageMap: pageMap,
                memoIndex: safeCurrentMemoIndex,
                chapterPageIndex: safeChapterPageIndex,
              );
        final pagedTotalPages =
            pageMap?.totalPages ??
            (widget.items.isEmpty
                ? 0
                : math.max(1, currentChapter?.pages.length ?? 1));
        final effectivePageAnimation =
            resolveEffectiveCollectionReaderPageAnimation(
              preferences.pageAnimation,
            );
        final sliderMax = preferences.mode == CollectionReaderMode.paged
            ? math.max(0, pagedTotalPages - 1).toDouble()
            : math.max(0, widget.items.length - 1).toDouble();
        final sliderValue =
            _sliderDragValue ??
            (preferences.mode == CollectionReaderMode.paged
                ? currentGlobalPageIndex
                      .clamp(0, math.max(0, pagedTotalPages - 1))
                      .toDouble()
                : _currentMemoIndex.toDouble());
        final progressText = preferences.mode == CollectionReaderMode.paged
            ? pagedTotalPages <= 0
                  ? context.t.strings.collections.reader.progressPage(
                      current: 0,
                      total: 0,
                    )
                  : context.t.strings.collections.reader.progressPage(
                      current:
                          currentGlobalPageIndex.clamp(0, pagedTotalPages - 1) +
                          1,
                      total: pagedTotalPages,
                    )
            : context.t.strings.collections.reader.progressMemo(
                current: _currentMemoIndex + 1,
                total: widget.items.length,
              );
        final currentPage =
            currentChapter == null || currentChapter.pages.isEmpty
            ? null
            : currentChapter.pages[safeChapterPageIndex];
        final previousPage = _resolveAdjacentPage(
          currentChapter: currentChapter,
          currentMemoIndex: safeCurrentMemoIndex,
          currentChapterPageIndex: safeChapterPageIndex,
          delta: -1,
          preferences: preferences,
        );
        final nextPage = _resolveAdjacentPage(
          currentChapter: currentChapter,
          currentMemoIndex: safeCurrentMemoIndex,
          currentChapterPageIndex: safeChapterPageIndex,
          delta: 1,
          preferences: preferences,
        );
        final currentSubtitle = () {
          if (currentMemo == null) {
            return '';
          }
          return buildCollectionReaderTocTitle(
            currentMemo,
            safeCurrentMemoIndex,
          );
        }();
        final headerData = CollectionReaderHeaderData(
          collectionTitle: widget.collectionTitle,
          currentItemTitle: currentSubtitle,
          currentItemMeta: currentMemo == null
              ? ''
              : buildCollectionReaderTocSubtitle(currentMemo),
          positionLabel: widget.items.isEmpty
              ? ''
              : '${safeCurrentMemoIndex + 1} / ${widget.items.length}',
          showTitleAddition: preferences.displayConfig.showReadTitleAddition,
        );
        void jumpToPreviousChapter() {
          _stopAutoPage();
          final targetMemoIndex = math.max(0, safeCurrentMemoIndex - 1);
          if (targetMemoIndex == safeCurrentMemoIndex) {
            return;
          }
          unawaited(
            _jumpToChapterPage(
              memoIndex: targetMemoIndex,
              chapterPageIndex: 0,
              hideEvent: CollectionReaderMenuEvent.chapterJumped,
              direction: ReaderPageTurnDirection.previous,
            ),
          );
        }

        void jumpToNextChapter() {
          _stopAutoPage();
          final targetMemoIndex = math.min(
            widget.items.length - 1,
            safeCurrentMemoIndex + 1,
          );
          if (targetMemoIndex == safeCurrentMemoIndex) {
            return;
          }
          unawaited(
            _jumpToChapterPage(
              memoIndex: targetMemoIndex,
              chapterPageIndex: 0,
              hideEvent: CollectionReaderMenuEvent.chapterJumped,
              direction: ReaderPageTurnDirection.next,
            ),
          );
        }

        if (pagedModeReady) {
          _retainPagedChapterLayouts();
        }
        final bodyTextStyle = readerTheme.textTheme.bodyLarge!.copyWith(
          fontSize: 18 * preferences.textScale,
          height: preferences.lineSpacing,
          color: palette.foreground,
          fontFamily: preferences.readerFontFamily,
          fontWeight: _resolveReaderFontWeight(preferences.fontWeightMode),
          letterSpacing: preferences.letterSpacing,
        );
        final metaTextStyle = readerTheme.textTheme.bodySmall!.copyWith(
          fontSize: 13 * preferences.textScale,
          height: 1.4,
          color: palette.foreground.withValues(alpha: 0.74),
          fontFamily: preferences.readerFontFamily,
          letterSpacing: preferences.letterSpacing,
        );
        return Theme(
          data: readerTheme,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.background,
                    image: palette.imageProvider == null
                        ? null
                        : DecorationImage(
                            image: palette.imageProvider!,
                            fit: BoxFit.cover,
                            opacity: preferences.backgroundConfig.alpha,
                          ),
                  ),
                  child: preferences.mode == CollectionReaderMode.vertical
                      ? CollectionReaderVerticalView(
                          viewportKey: _verticalViewportKey,
                          scrollController: _verticalController,
                          items: widget.items,
                          itemKeys: _verticalItemKeys,
                          highlightQuery: _highlightQuery,
                          highlightMemoUid: _highlightMemoUid,
                          pagePadding: preferences.pagePadding,
                          contentTextStyle: bodyTextStyle,
                          metaTextStyle: metaTextStyle,
                          allowTextSelection:
                              preferences.displayConfig.allowTextSelection,
                          previewImageOnTap:
                              preferences.displayConfig.previewImageOnTap,
                          onCenterTap: _toggleOverlay,
                          onChapterMeasured: (index, height) {
                            _memoHeights[index] = height;
                          },
                          onUserScrollStart: _stopAutoPage,
                        )
                      : CollectionReaderPagedView(
                          currentPage: currentPage,
                          previousPage: previousPage,
                          nextPage: nextPage,
                          canGoPrevious: previousPage != null,
                          canGoNext: nextPage != null,
                          preferences: preferences,
                          turnDirection: _turnDirection,
                          highlightQuery: _highlightQuery,
                          highlightMemoUid: _highlightMemoUid,
                          collectionTitle: widget.collectionTitle,
                          currentGlobalPageIndex: currentGlobalPageIndex,
                          totalPages: pagedTotalPages,
                          previewImageOnTap:
                              preferences.displayConfig.previewImageOnTap,
                          onShowSearch: () => _showSearchSheet(preferences),
                          onShowToc: _showTocSheet,
                          onPrevChapter: jumpToPreviousChapter,
                          onNextChapter: jumpToNextChapter,
                          onCenterTap: _toggleOverlay,
                          onPrevPage: () {
                            _stopAutoPage();
                            _goToAdjacentPage(-1);
                          },
                          onNextPage: () {
                            _stopAutoPage();
                            _goToAdjacentPage(1);
                          },
                          onUserInteraction: _stopAutoPage,
                        ),
                ),
              ),
              if (preferences.displayConfig.showBrightnessOverlay &&
                  !_platformBrightnessSupported &&
                  preferences.brightnessMode ==
                      CollectionReaderBrightnessMode.manual &&
                  preferences.brightness < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: (1 - preferences.brightness) * 0.55,
                      ),
                    ),
                  ),
                ),
              AnimatedOpacity(
                opacity: _menuState == CollectionReaderMenuState.overlayVisible
                    ? 1
                    : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring:
                      _menuState != CollectionReaderMenuState.overlayVisible,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleOverlay,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
              CollectionReaderOverlay(
                visible: _menuState == CollectionReaderMenuState.overlayVisible,
                headerData: headerData,
                readerMode: preferences.mode,
                pageAnimation: effectivePageAnimation,
                themePreset: preferences.themePreset,
                currentProgressText: progressText,
                sliderValue: sliderValue,
                sliderMax: sliderMax,
                autoPaging: _autoPaging,
                canPrevChapter: safeCurrentMemoIndex > 0,
                canNextChapter: safeCurrentMemoIndex < widget.items.length - 1,
                showBrightnessControl:
                    preferences.displayConfig.showBrightnessOverlay,
                brightnessMode: preferences.brightnessMode,
                brightness: preferences.brightness,
                followPageStyle:
                    preferences.displayConfig.followPageStyleForBars,
                pageBackgroundColor: palette.background,
                pageForegroundColor: palette.foreground,
                accentColor: palette.accent,
                hostBrightness: baseTheme.brightness,
                onBack: () {
                  _dispatchMenuEvent(CollectionReaderMenuEvent.readerExited);
                  Navigator.of(context).maybePop();
                },
                onSearch: () => _showSearchSheet(preferences),
                onMoreSelected: (action) =>
                    _handleMoreAction(action, currentCollection, currentMemo),
                onProgressTap: _showTocSheet,
                onToggleThemePreset: () {
                  final targetPreset =
                      preferences.themePreset ==
                          CollectionReaderThemePreset.dark
                      ? CollectionReaderThemePreset.paper
                      : CollectionReaderThemePreset.dark;
                  preferencesNotifier.setCollectionReaderThemePreset(
                    targetPreset,
                  );
                },
                onModeChanged: _applyReaderMode,
                onAnimationChanged: _updatePageAnimation,
                onShowToc: _showTocSheet,
                onShowAutoPage: () => _showAutoPageSheet(preferences),
                onShowStyle: () => _showStyleSheet(preferences),
                onShowMoreSettings: () => _showMoreSettingsSheet(preferences),
                onPrevChapter: jumpToPreviousChapter,
                onNextChapter: jumpToNextChapter,
                onBrightnessModeChanged:
                    preferencesNotifier.setCollectionReaderBrightnessMode,
                onBrightnessChanged:
                    preferencesNotifier.setCollectionReaderBrightness,
                onSliderChanged: (value) {
                  setState(() => _sliderDragValue = value);
                },
                onSliderChangeEnd: (value) {
                  final target = value.round();
                  setState(() => _sliderDragValue = null);
                  if (preferences.mode == CollectionReaderMode.paged &&
                      pageMap != null &&
                      pageMap.totalPages > 0) {
                    final targetPage = _pageEngine
                        .resolvePageTargetForGlobalIndex(
                          pageMap: pageMap,
                          globalPageIndex: target,
                        );
                    if (targetPage == null) {
                      return;
                    }
                    unawaited(
                      _jumpToChapterPage(
                        memoIndex: targetPage.memoIndex,
                        chapterPageIndex: targetPage.chapterPageIndex,
                        hideEvent: CollectionReaderMenuEvent.chapterJumped,
                        direction: _resolveDirectionForTarget(
                          targetPage.memoIndex,
                          chapterPageIndex: targetPage.chapterPageIndex,
                          preferences: preferences,
                        ),
                      ),
                    );
                  } else {
                    _setCurrentMemoIndex(target);
                    unawaited(_jumpVerticalToIndex(target));
                  }
                },
                onOverlayInteraction: _handleOverlayInteraction,
              ),
            ],
          ),
        );
      },
    );
    return Scaffold(
      body: preferences.displayConfig.padDisplayCutouts
          ? SafeArea(child: readerBody)
          : readerBody,
    );
  }
}

enum _CurrentMemoAction { open, copy, addToCollection, togglePin }

FontWeight _resolveReaderFontWeight(CollectionReaderFontWeightMode mode) {
  return switch (mode) {
    CollectionReaderFontWeightMode.normal => FontWeight.w400,
    CollectionReaderFontWeightMode.medium => FontWeight.w500,
    CollectionReaderFontWeightMode.bold => FontWeight.w700,
  };
}
