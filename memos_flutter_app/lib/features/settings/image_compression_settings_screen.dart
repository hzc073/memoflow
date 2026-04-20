import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/memoflow_palette.dart';
import '../../data/models/image_compression_settings.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/image_compression_settings_provider.dart';

class ImageCompressionSettingsScreen extends ConsumerWidget {
  const ImageCompressionSettingsScreen({super.key});

  static const int _dimensionStep = 160;
  static const int _qualityStep = 5;
  static const int _sizeStep = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageCompressionSettingsProvider);
    final notifier = ref.read(imageCompressionSettingsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? MemoFlowPalette.backgroundDark
        : MemoFlowPalette.backgroundLight;
    final card = isDark ? MemoFlowPalette.cardDark : MemoFlowPalette.cardLight;
    final textMain = isDark
        ? MemoFlowPalette.textDark
        : MemoFlowPalette.textLight;
    final textMuted = textMain.withValues(alpha: isDark ? 0.55 : 0.6);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final showLosslessWarning =
        settings.lossless &&
        (settings.outputFormat != ImageCompressionOutputFormat.sameAsInput ||
            settings.resize.enabled) &&
        settings.mode == ImageCompressionMode.quality;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.t.strings.legacy.msg_back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.t.strings.legacy.msg_image_compression),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ToggleCard(
            card: card,
            textMain: textMain,
            textMuted: textMuted,
            label: context.t.strings.legacy.msg_enable_image_compression,
            description: context.t.strings.legacy.msg_image_compression_desc,
            value: settings.enabled,
            onChanged: notifier.setEnabled,
          ),
          if (showLosslessWarning) ...[
            const SizedBox(height: 12),
            _WarningCard(
              card: card,
              textMain: textMain,
              textMuted: textMuted,
              message: context.t.strings.legacy.msg_lossless_warning,
            ),
          ],
          const SizedBox(height: 16),
          _SectionTitle(context.t.strings.legacy.msg_basics, textMuted),
          const SizedBox(height: 10),
          _Group(
            card: card,
            divider: divider,
            children: [
              _SelectMenuRow<ImageCompressionMode>(
                label: context.t.strings.legacy.msg_compression_mode,
                textMain: textMain,
                textMuted: textMuted,
                currentValue: settings.mode,
                items: ImageCompressionMode.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_modeLabel(context, value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: notifier.setMode,
              ),
              _SelectMenuRow<ImageCompressionOutputFormat>(
                label: context.t.strings.legacy.msg_output_format,
                textMain: textMain,
                textMuted: textMuted,
                currentValue: settings.outputFormat,
                items: ImageCompressionOutputFormat.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_outputFormatLabel(context, value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: notifier.setOutputFormat,
              ),
              _SwitchRow(
                label: context.t.strings.legacy.msg_lossless,
                value: settings.lossless,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: notifier.setLossless,
              ),
              _SwitchRow(
                label: context.t.strings.legacy.msg_keep_metadata,
                value: settings.keepMetadata,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: notifier.setKeepMetadata,
              ),
              _SwitchRow(
                label: context.t.strings.legacy.msg_skip_if_bigger,
                value: settings.skipIfBigger,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: notifier.setSkipIfBigger,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionTitle(context.t.strings.legacy.msg_resize, textMuted),
          const SizedBox(height: 10),
          _Group(
            card: card,
            divider: divider,
            children: [
              _SwitchRow(
                label: context.t.strings.legacy.msg_enable_resize,
                value: settings.resize.enabled,
                textMain: textMain,
                textMuted: textMuted,
                onChanged: notifier.setResizeEnabled,
              ),
              _SelectMenuRow<ImageCompressionResizeMode>(
                label: context.t.strings.legacy.msg_resize_mode,
                textMain: textMain,
                textMuted: textMuted,
                currentValue: settings.resize.mode,
                items: ImageCompressionResizeMode.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_resizeModeLabel(context, value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: notifier.setResizeMode,
                enabled: settings.resize.enabled,
              ),
              if (_needsWidth(settings.resize.mode))
                _StepperRow(
                  label: context.t.strings.legacy.msg_resize_width,
                  value: settings.resize.width,
                  unit:
                      settings.resize.mode ==
                          ImageCompressionResizeMode.percentage
                      ? '%'
                      : 'px',
                  textMain: textMain,
                  textMuted: textMuted,
                  enabled: settings.resize.enabled,
                  onDecrease: () => notifier.setResizeWidth(
                    settings.resize.width -
                        (settings.resize.mode ==
                                ImageCompressionResizeMode.percentage
                            ? _sizeStep
                            : _dimensionStep),
                  ),
                  onIncrease: () => notifier.setResizeWidth(
                    settings.resize.width +
                        (settings.resize.mode ==
                                ImageCompressionResizeMode.percentage
                            ? _sizeStep
                            : _dimensionStep),
                  ),
                ),
              if (_needsHeight(settings.resize.mode))
                _StepperRow(
                  label: context.t.strings.legacy.msg_resize_height,
                  value: settings.resize.height,
                  unit:
                      settings.resize.mode ==
                          ImageCompressionResizeMode.percentage
                      ? '%'
                      : 'px',
                  textMain: textMain,
                  textMuted: textMuted,
                  enabled: settings.resize.enabled,
                  onDecrease: () => notifier.setResizeHeight(
                    settings.resize.height -
                        (settings.resize.mode ==
                                ImageCompressionResizeMode.percentage
                            ? _sizeStep
                            : _dimensionStep),
                  ),
                  onIncrease: () => notifier.setResizeHeight(
                    settings.resize.height +
                        (settings.resize.mode ==
                                ImageCompressionResizeMode.percentage
                            ? _sizeStep
                            : _dimensionStep),
                  ),
                ),
              if (_needsEdge(settings.resize.mode))
                _StepperRow(
                  label: context.t.strings.legacy.msg_resize_edge,
                  value: settings.resize.edge,
                  unit: 'px',
                  textMain: textMain,
                  textMuted: textMuted,
                  enabled: settings.resize.enabled,
                  onDecrease: () => notifier.setResizeEdge(
                    settings.resize.edge - _dimensionStep,
                  ),
                  onIncrease: () => notifier.setResizeEdge(
                    settings.resize.edge + _dimensionStep,
                  ),
                ),
              _SwitchRow(
                label: context.t.strings.legacy.msg_do_not_enlarge,
                value: settings.resize.doNotEnlarge,
                textMain: textMain,
                textMuted: textMuted,
                enabled: settings.resize.enabled,
                onChanged: notifier.setResizeDoNotEnlarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCodecSections(
            context: context,
            settings: settings,
            notifier: notifier,
            card: card,
            divider: divider,
            textMain: textMain,
            textMuted: textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            context.t.strings.legacy.msg_image_compression_scope,
            style: TextStyle(fontSize: 12, height: 1.35, color: textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildCodecSections({
    required BuildContext context,
    required ImageCompressionSettings settings,
    required ImageCompressionSettingsController notifier,
    required Color card,
    required Color divider,
    required Color textMain,
    required Color textMuted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: context.t.strings.legacy.msg_jpeg,
          color: textMuted,
          child: _Group(
            card: card,
            divider: divider,
            children: [
              _StepperRow(
                label: context.t.strings.legacy.msg_quality,
                value: settings.jpeg.quality,
                unit: '%',
                textMain: textMain,
                textMuted: textMuted,
                enabled: !settings.lossless,
                onDecrease: () => notifier.setJpegQuality(
                  settings.jpeg.quality - _qualityStep,
                ),
                onIncrease: () => notifier.setJpegQuality(
                  settings.jpeg.quality + _qualityStep,
                ),
              ),
              _SelectMenuRow<JpegChromaSubsampling>(
                label: context.t.strings.legacy.msg_chroma_subsampling,
                textMain: textMain,
                textMuted: textMuted,
                currentValue: settings.jpeg.chromaSubsampling,
                items: JpegChromaSubsampling.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_chromaLabel(context, value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: notifier.setJpegChromaSubsampling,
                enabled: !settings.lossless,
              ),
              _SwitchRow(
                label: context.t.strings.legacy.msg_progressive,
                value: settings.jpeg.progressive,
                textMain: textMain,
                textMuted: textMuted,
                enabled: !settings.lossless,
                onChanged: notifier.setJpegProgressive,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: context.t.strings.legacy.msg_png,
          color: textMuted,
          child: _Group(
            card: card,
            divider: divider,
            children: [
              _StepperRow(
                label: context.t.strings.legacy.msg_quality,
                value: settings.png.quality,
                unit: '%',
                textMain: textMain,
                textMuted: textMuted,
                enabled: !settings.lossless,
                onDecrease: () =>
                    notifier.setPngQuality(settings.png.quality - _qualityStep),
                onIncrease: () =>
                    notifier.setPngQuality(settings.png.quality + _qualityStep),
              ),
              _StepperRow(
                label: context.t.strings.legacy.msg_optimization_level,
                value: settings.png.optimizationLevel,
                unit: '',
                textMain: textMain,
                textMuted: textMuted,
                enabled: settings.lossless,
                onDecrease: () => notifier.setPngOptimizationLevel(
                  settings.png.optimizationLevel - 1,
                ),
                onIncrease: () => notifier.setPngOptimizationLevel(
                  settings.png.optimizationLevel + 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: context.t.strings.legacy.msg_webp,
          color: textMuted,
          child: _Group(
            card: card,
            divider: divider,
            children: [
              _StepperRow(
                label: context.t.strings.legacy.msg_quality,
                value: settings.webp.quality,
                unit: '%',
                textMain: textMain,
                textMuted: textMuted,
                enabled: !settings.lossless,
                onDecrease: () => notifier.setWebpQuality(
                  settings.webp.quality - _qualityStep,
                ),
                onIncrease: () => notifier.setWebpQuality(
                  settings.webp.quality + _qualityStep,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: context.t.strings.legacy.msg_tiff,
          color: textMuted,
          child: _Group(
            card: card,
            divider: divider,
            children: [
              _SelectMenuRow<TiffCompressionMethod>(
                label: context.t.strings.legacy.msg_method,
                textMain: textMain,
                textMuted: textMuted,
                currentValue: settings.tiff.method,
                items: TiffCompressionMethod.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_tiffMethodLabel(context, value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: notifier.setTiffMethod,
              ),
              _SelectMenuRow<TiffDeflatePreset>(
                label: context.t.strings.legacy.msg_deflate_preset,
                textMain: textMain,
                textMuted: textMuted,
                currentValue: settings.tiff.deflatePreset,
                items: TiffDeflatePreset.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_tiffPresetLabel(context, value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: notifier.setTiffDeflatePreset,
                enabled: settings.tiff.method == TiffCompressionMethod.deflate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: context.t.strings.legacy.msg_mode_size,
          color: textMuted,
          child: _Group(
            card: card,
            divider: divider,
            children: [
              _StepperRow(
                label: context.t.strings.legacy.msg_size_target,
                value: settings.sizeTarget.value,
                unit: _sizeUnitLabel(context, settings.sizeTarget.unit),
                textMain: textMain,
                textMuted: textMuted,
                enabled: settings.mode == ImageCompressionMode.size,
                onDecrease: () => notifier.setSizeTargetValue(
                  settings.sizeTarget.value - _sizeStep,
                ),
                onIncrease: () => notifier.setSizeTargetValue(
                  settings.sizeTarget.value + _sizeStep,
                ),
              ),
              _SelectMenuRow<ImageCompressionMaxOutputUnit>(
                label: context.t.strings.legacy.msg_output_size_unit,
                textMain: textMain,
                textMuted: textMuted,
                currentValue: settings.sizeTarget.unit,
                items: ImageCompressionMaxOutputUnit.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_sizeUnitLabel(context, value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: notifier.setSizeTargetUnit,
                enabled: settings.mode == ImageCompressionMode.size,
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _needsWidth(ImageCompressionResizeMode mode) =>
      mode == ImageCompressionResizeMode.dimensions ||
      mode == ImageCompressionResizeMode.percentage ||
      mode == ImageCompressionResizeMode.fixedWidth;
  bool _needsHeight(ImageCompressionResizeMode mode) =>
      mode == ImageCompressionResizeMode.dimensions ||
      mode == ImageCompressionResizeMode.percentage ||
      mode == ImageCompressionResizeMode.fixedHeight;
  bool _needsEdge(ImageCompressionResizeMode mode) =>
      mode == ImageCompressionResizeMode.shortEdge ||
      mode == ImageCompressionResizeMode.longEdge;

  String _modeLabel(BuildContext context, ImageCompressionMode value) =>
      switch (value) {
        ImageCompressionMode.quality =>
          context.t.strings.legacy.msg_mode_quality,
        ImageCompressionMode.size => context.t.strings.legacy.msg_mode_size,
      };

  String _outputFormatLabel(
    BuildContext context,
    ImageCompressionOutputFormat value,
  ) => switch (value) {
    ImageCompressionOutputFormat.sameAsInput =>
      context.t.strings.legacy.msg_output_format_same_as_input,
    ImageCompressionOutputFormat.jpeg =>
      context.t.strings.legacy.msg_format_jpeg,
    ImageCompressionOutputFormat.png => context.t.strings.legacy.msg_format_png,
    ImageCompressionOutputFormat.webp =>
      context.t.strings.legacy.msg_format_webp,
    ImageCompressionOutputFormat.tiff =>
      context.t.strings.legacy.msg_format_tiff,
  };

  String _resizeModeLabel(
    BuildContext context,
    ImageCompressionResizeMode value,
  ) => switch (value) {
    ImageCompressionResizeMode.noResize =>
      context.t.strings.legacy.msg_resize_mode_no_resize,
    ImageCompressionResizeMode.dimensions =>
      context.t.strings.legacy.msg_resize_mode_dimensions,
    ImageCompressionResizeMode.percentage =>
      context.t.strings.legacy.msg_resize_mode_percentage,
    ImageCompressionResizeMode.shortEdge =>
      context.t.strings.legacy.msg_resize_mode_short_edge,
    ImageCompressionResizeMode.longEdge =>
      context.t.strings.legacy.msg_resize_mode_long_edge,
    ImageCompressionResizeMode.fixedWidth =>
      context.t.strings.legacy.msg_resize_mode_fixed_width,
    ImageCompressionResizeMode.fixedHeight =>
      context.t.strings.legacy.msg_resize_mode_fixed_height,
  };

  Widget _buildSection({
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title, color),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  String _chromaLabel(
    BuildContext context,
    JpegChromaSubsampling value,
  ) => switch (value) {
    JpegChromaSubsampling.auto => context.t.strings.legacy.msg_chroma_auto,
    JpegChromaSubsampling.chroma444 => context.t.strings.legacy.msg_chroma_444,
    JpegChromaSubsampling.chroma422 => context.t.strings.legacy.msg_chroma_422,
    JpegChromaSubsampling.chroma420 => context.t.strings.legacy.msg_chroma_420,
    JpegChromaSubsampling.chroma411 => context.t.strings.legacy.msg_chroma_411,
  };

  String _tiffMethodLabel(BuildContext context, TiffCompressionMethod value) =>
      switch (value) {
        TiffCompressionMethod.uncompressed =>
          context.t.strings.legacy.msg_uncompressed,
        TiffCompressionMethod.lzw => context.t.strings.legacy.msg_lzw,
        TiffCompressionMethod.deflate => context.t.strings.legacy.msg_deflate,
        TiffCompressionMethod.packbits => context.t.strings.legacy.msg_packbits,
      };

  String _tiffPresetLabel(BuildContext context, TiffDeflatePreset value) =>
      switch (value) {
        TiffDeflatePreset.fast => context.t.strings.legacy.msg_fast,
        TiffDeflatePreset.balanced => context.t.strings.legacy.msg_balanced,
        TiffDeflatePreset.best => context.t.strings.legacy.msg_best,
      };

  String _sizeUnitLabel(
    BuildContext context,
    ImageCompressionMaxOutputUnit value,
  ) => switch (value) {
    ImageCompressionMaxOutputUnit.bytes => context.t.strings.legacy.msg_bytes,
    ImageCompressionMaxOutputUnit.kb => context.t.strings.legacy.msg_kb,
    ImageCompressionMaxOutputUnit.mb => context.t.strings.legacy.msg_mb,
    ImageCompressionMaxOutputUnit.percentage =>
      context.t.strings.legacy.msg_percentage,
  };
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.color);

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.card,
    required this.divider,
    required this.children,
  });

  final Color card;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: divider),
          ],
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
          if (description.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 44),
              child: Text(
                description,
                style: TextStyle(fontSize: 12, color: textMuted, height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.card,
    required this.textMain,
    required this.textMuted,
    required this.message,
  });

  final Color card;
  final Color textMain;
  final Color textMuted;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: textMain),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.textMain,
    required this.textMuted,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final Color textMain;
  final Color textMuted;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.textMain,
    required this.textMuted,
    required this.onDecrease,
    required this.onIncrease,
    this.enabled = true,
  });

  final String label;
  final int value;
  final String unit;
  final Color textMain;
  final Color textMuted;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    Widget buildButton(IconData icon, VoidCallback onTap) {
      return InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: textMuted),
        ),
      );
    }

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: textMain),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: pillBorder),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildButton(Icons.remove, onDecrease),
                  const SizedBox(width: 6),
                  Text(
                    unit.isEmpty ? '$value' : '$value$unit',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(width: 6),
                  buildButton(Icons.add, onIncrease),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectMenuRow<T> extends StatelessWidget {
  const _SelectMenuRow({
    required this.label,
    required this.textMain,
    required this.textMuted,
    required this.currentValue,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final Color textMain;
  final Color textMuted;
  final T currentValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: currentValue,
                  items: items,
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
