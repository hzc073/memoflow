import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/image_compression_settings.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/image_compression_settings_provider.dart';
import 'settings_ui.dart';

class ImageCompressionSettingsScreen extends ConsumerWidget {
  const ImageCompressionSettingsScreen({super.key});

  static const int _dimensionStep = 160;
  static const int _qualityStep = 5;
  static const int _sizeStep = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(imageCompressionSettingsProvider);
    final notifier = ref.read(imageCompressionSettingsProvider.notifier);
    final showLosslessWarning =
        settings.lossless &&
        (settings.outputFormat != ImageCompressionOutputFormat.sameAsInput ||
            settings.resize.enabled) &&
        settings.mode == ImageCompressionMode.quality;

    return SettingsPage(
      title: Text(context.t.strings.legacy.msg_image_compression),
      children: [
        SettingsToggleCard(
          label: context.t.strings.legacy.msg_enable_image_compression,
          description: context.t.strings.legacy.msg_image_compression_desc,
          value: settings.enabled,
          onChanged: notifier.setEnabled,
        ),
        if (showLosslessWarning) ...[
          const SizedBox(height: 12),
          SettingsSection(
            children: [
              SettingsWarningRow(
                message: context.t.strings.legacy.msg_lossless_warning,
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_basics),
          children: [
            SettingsMenuRow<ImageCompressionMode>(
              label: context.t.strings.legacy.msg_compression_mode,
              value: settings.mode,
              values: ImageCompressionMode.values,
              labelFor: (value) => _modeLabel(context, value),
              onChanged: notifier.setMode,
            ),
            SettingsMenuRow<ImageCompressionOutputFormat>(
              label: context.t.strings.legacy.msg_output_format,
              value: settings.outputFormat,
              values: ImageCompressionOutputFormat.values,
              labelFor: (value) => _outputFormatLabel(context, value),
              onChanged: notifier.setOutputFormat,
            ),
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_lossless,
              value: settings.lossless,
              onChanged: notifier.setLossless,
            ),
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_keep_metadata,
              value: settings.keepMetadata,
              onChanged: notifier.setKeepMetadata,
            ),
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_skip_if_bigger,
              value: settings.skipIfBigger,
              onChanged: notifier.setSkipIfBigger,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_resize),
          children: [
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_enable_resize,
              value: settings.resize.enabled,
              onChanged: notifier.setResizeEnabled,
            ),
            SettingsMenuRow<ImageCompressionResizeMode>(
              label: context.t.strings.legacy.msg_resize_mode,
              value: settings.resize.mode,
              values: ImageCompressionResizeMode.values,
              labelFor: (value) => _resizeModeLabel(context, value),
              onChanged: notifier.setResizeMode,
              enabled: settings.resize.enabled,
            ),
            if (_needsWidth(settings.resize.mode))
              SettingsStepperRow(
                label: context.t.strings.legacy.msg_resize_width,
                value: settings.resize.width,
                unit:
                    settings.resize.mode ==
                        ImageCompressionResizeMode.percentage
                    ? '%'
                    : 'px',
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
              SettingsStepperRow(
                label: context.t.strings.legacy.msg_resize_height,
                value: settings.resize.height,
                unit:
                    settings.resize.mode ==
                        ImageCompressionResizeMode.percentage
                    ? '%'
                    : 'px',
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
              SettingsStepperRow(
                label: context.t.strings.legacy.msg_resize_edge,
                value: settings.resize.edge,
                unit: 'px',
                enabled: settings.resize.enabled,
                onDecrease: () => notifier.setResizeEdge(
                  settings.resize.edge - _dimensionStep,
                ),
                onIncrease: () => notifier.setResizeEdge(
                  settings.resize.edge + _dimensionStep,
                ),
              ),
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_do_not_enlarge,
              value: settings.resize.doNotEnlarge,
              onChanged: settings.resize.enabled
                  ? notifier.setResizeDoNotEnlarge
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCodecSections(
          context: context,
          settings: settings,
          notifier: notifier,
        ),
        const SizedBox(height: 12),
        SettingsInfoRow(
          description: context.t.strings.legacy.msg_image_compression_scope,
        ),
      ],
    );
  }

  Widget _buildCodecSections({
    required BuildContext context,
    required ImageCompressionSettings settings,
    required ImageCompressionSettingsController notifier,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_jpeg),
          children: [
            SettingsStepperRow(
              label: context.t.strings.legacy.msg_quality,
              value: settings.jpeg.quality,
              unit: '%',
              enabled: !settings.lossless,
              onDecrease: () =>
                  notifier.setJpegQuality(settings.jpeg.quality - _qualityStep),
              onIncrease: () =>
                  notifier.setJpegQuality(settings.jpeg.quality + _qualityStep),
            ),
            SettingsMenuRow<JpegChromaSubsampling>(
              label: context.t.strings.legacy.msg_chroma_subsampling,
              value: settings.jpeg.chromaSubsampling,
              values: JpegChromaSubsampling.values,
              labelFor: (value) => _chromaLabel(context, value),
              onChanged: notifier.setJpegChromaSubsampling,
              enabled: !settings.lossless,
            ),
            SettingsToggleRow(
              label: context.t.strings.legacy.msg_progressive,
              value: settings.jpeg.progressive,
              onChanged: !settings.lossless
                  ? notifier.setJpegProgressive
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_png),
          children: [
            SettingsStepperRow(
              label: context.t.strings.legacy.msg_quality,
              value: settings.png.quality,
              unit: '%',
              enabled: !settings.lossless,
              onDecrease: () =>
                  notifier.setPngQuality(settings.png.quality - _qualityStep),
              onIncrease: () =>
                  notifier.setPngQuality(settings.png.quality + _qualityStep),
            ),
            SettingsStepperRow(
              label: context.t.strings.legacy.msg_optimization_level,
              value: settings.png.optimizationLevel,
              unit: '',
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
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_webp),
          children: [
            SettingsStepperRow(
              label: context.t.strings.legacy.msg_quality,
              value: settings.webp.quality,
              unit: '%',
              enabled: !settings.lossless,
              onDecrease: () =>
                  notifier.setWebpQuality(settings.webp.quality - _qualityStep),
              onIncrease: () =>
                  notifier.setWebpQuality(settings.webp.quality + _qualityStep),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_tiff),
          children: [
            SettingsMenuRow<TiffCompressionMethod>(
              label: context.t.strings.legacy.msg_method,
              value: settings.tiff.method,
              values: TiffCompressionMethod.values,
              labelFor: (value) => _tiffMethodLabel(context, value),
              onChanged: notifier.setTiffMethod,
            ),
            SettingsMenuRow<TiffDeflatePreset>(
              label: context.t.strings.legacy.msg_deflate_preset,
              value: settings.tiff.deflatePreset,
              values: TiffDeflatePreset.values,
              labelFor: (value) => _tiffPresetLabel(context, value),
              onChanged: notifier.setTiffDeflatePreset,
              enabled: settings.tiff.method == TiffCompressionMethod.deflate,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsSection(
          header: Text(context.t.strings.legacy.msg_mode_size),
          children: [
            SettingsStepperRow(
              label: context.t.strings.legacy.msg_size_target,
              value: settings.sizeTarget.value,
              unit: _sizeTargetValueUnitLabel(
                context,
                settings.sizeTarget.unit,
              ),
              enabled: settings.mode == ImageCompressionMode.size,
              onDecrease: () => notifier.setSizeTargetValue(
                settings.sizeTarget.value - _sizeStep,
              ),
              onIncrease: () => notifier.setSizeTargetValue(
                settings.sizeTarget.value + _sizeStep,
              ),
            ),
            SettingsMenuRow<ImageCompressionMaxOutputUnit>(
              label: context.t.strings.legacy.msg_output_size_unit,
              value: settings.sizeTarget.unit,
              values: ImageCompressionMaxOutputUnit.values,
              labelFor: (value) => _sizeUnitLabel(context, value),
              onChanged: notifier.setSizeTargetUnit,
              enabled: settings.mode == ImageCompressionMode.size,
            ),
          ],
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

  String _sizeTargetValueUnitLabel(
    BuildContext context,
    ImageCompressionMaxOutputUnit value,
  ) => switch (value) {
    ImageCompressionMaxOutputUnit.percentage => '%',
    _ => _sizeUnitLabel(context, value),
  };
}
