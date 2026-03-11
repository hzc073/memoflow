import 'package:flutter/material.dart';

import '../../data/location/location_provider_bundle.dart';
import '../../i18n/strings.g.dart';
import 'embedded_map_host.dart';
import 'location_picker_controller.dart';
import 'location_picker_i18n.dart';

class LocationPickerSheet extends StatelessWidget {
  const LocationPickerSheet({
    super.key,
    required this.controller,
    required this.mapHostController,
    required this.bundle,
    this.mapHostChild,
  });

  final LocationPickerController controller;
  final EmbeddedMapHostBridgeController mapHostController;
  final LocationProviderBundle bundle;
  final Widget? mapHostChild;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.92,
          child: _LocationPickerPanel(
            controller: controller,
            mapHostController: mapHostController,
            bundle: bundle,
            mapHostChild: mapHostChild,
          ),
        ),
      ),
    );
  }
}

class LocationPickerPanel extends StatelessWidget {
  const LocationPickerPanel({
    super.key,
    required this.controller,
    required this.mapHostController,
    required this.bundle,
    this.mapHostChild,
  });

  final LocationPickerController controller;
  final EmbeddedMapHostBridgeController mapHostController;
  final LocationProviderBundle bundle;
  final Widget? mapHostChild;

  @override
  Widget build(BuildContext context) {
    return _LocationPickerPanel(
      controller: controller,
      mapHostController: mapHostController,
      bundle: bundle,
      mapHostChild: mapHostChild,
    );
  }
}

class _LocationPickerPanel extends StatelessWidget {
  const _LocationPickerPanel({
    required this.controller,
    required this.mapHostController,
    required this.bundle,
    this.mapHostChild,
  });

  final LocationPickerController controller;
  final EmbeddedMapHostBridgeController mapHostController;
  final LocationProviderBundle bundle;
  final Widget? mapHostChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final candidates = controller.visibleCandidates;
        final errorText = localizeLocationPickerError(
          context,
          state.errorMessage,
        );
        return Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: controller.onQueryChanged,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: context
                              .t
                              .strings
                              .locationPicker
                              .searchNearbyPlaces,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        state.providerLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 260,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        mapHostChild ??
                            EmbeddedMapHost(
                              controller: mapHostController,
                              bundle: bundle,
                            ),
                        IgnorePointer(
                          child: Center(
                            child: Transform.translate(
                              offset: const Offset(0, -14),
                              child: Icon(
                                Icons.place,
                                size: 40,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                        if (state.loading)
                          const ColoredBox(
                            color: Color(0x22000000),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            context.t.strings.locationPicker.latitudeValue(
                              value: state.currentCenter.latitude
                                  .toStringAsFixed(6),
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            context.t.strings.locationPicker.longitudeValue(
                              value: state.currentCenter.longitude
                                  .toStringAsFixed(6),
                            ),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (state.searching)
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              if (errorText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      errorText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: candidates.isEmpty
                    ? Center(
                        child: Text(
                          context.t.strings.locationPicker.noPlacesFound,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final selected =
                              controller.isSelected(candidate) ||
                              (index == 0 &&
                                  controller.state.selectedCandidate == null &&
                                  controller.state.query.trim().isEmpty);
                          return Material(
                            color: selected
                                ? theme.colorScheme.primaryContainer.withValues(
                                    alpha: 0.7,
                                  )
                                : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  controller.selectCandidate(candidate),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.place_outlined,
                                      color: selected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            candidate.title,
                                            style: theme.textTheme.titleSmall,
                                          ),
                                          if (candidate
                                              .displaySubtitle
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              candidate.displaySubtitle,
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (candidate.distanceMeters != null)
                                      Text(
                                        '${candidate.distanceMeters!.round()}m',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 8),
                        itemCount: candidates.length,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t.strings.common.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: state.confirming
                            ? null
                            : () async {
                                final result = await controller
                                    .confirmSelection();
                                if (!context.mounted) return;
                                Navigator.of(context).pop(result);
                              },
                        child: state.confirming
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(context.t.strings.common.confirm),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
