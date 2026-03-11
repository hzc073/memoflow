import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/location/location_provider_bundle_factory.dart';
import '../../data/location/location_provider_requirements_validator.dart';
import '../../data/location/models/canonical_coordinate.dart';
import '../../data/models/location_settings.dart';
import '../../data/models/memo_location.dart';
import '../../features/settings/location_settings_screen.dart';
import '../../i18n/strings.g.dart';
import '../../state/settings/location_settings_provider.dart';
import 'embedded_map_host.dart';
import 'location_picker_controller.dart';
import 'location_picker_dialog.dart';
import 'location_picker_i18n.dart';
import 'location_picker_logger.dart';
import 'location_picker_sheet.dart';

const _fallbackPickerCenter = CanonicalCoordinate(
  latitude: 39.9042,
  longitude: 116.4074,
);
const _fallbackPickerZoom = 11.0;
const _defaultPickerZoom = 16.0;

Future<MemoLocation?> showLocationPickerSheetOrDialog({
  required BuildContext context,
  required WidgetRef ref,
  MemoLocation? initialLocation,
}) async {
  LocationPickerLogger.info(
    'open_requested',
    context: {
      'platform': Platform.operatingSystem,
      'hasInitialLocation': initialLocation != null,
      'initialLatitude': initialLocation?.latitude,
      'initialLongitude': initialLocation?.longitude,
      'initialPlaceholder': initialLocation?.placeholder,
      'presentation': Platform.isWindows ? 'dialog' : 'sheet',
    },
  );
  final settings = await _resolveLocationSettings(ref);
  if (!context.mounted) return null;

  LocationPickerLogger.info(
    'settings_resolved',
    context: {
      'enabled': settings.enabled,
      'provider': settings.provider.name,
      'hasAmapKey': settings.amapWebKey.trim().isNotEmpty,
      'hasAmapSecurityKey': settings.amapSecurityKey.trim().isNotEmpty,
      'hasBaiduKey': settings.baiduWebKey.trim().isNotEmpty,
      'hasGoogleKey': settings.googleApiKey.trim().isNotEmpty,
    },
  );

  final validator = const LocationProviderRequirementsValidator();
  final result = validator.validate(settings);
  if (!result.isReady) {
    LocationPickerLogger.warn(
      'provider_not_ready',
      context: {
        'provider': settings.provider.name,
        'failure': result.failure?.name,
      },
    );
    await _showSettingsPrompt(
      context,
      localizeLocationProviderRequirement(context, result),
    );
    return null;
  }

  LocationPickerLogger.info(
    'provider_ready',
    context: {'provider': settings.provider.name},
  );

  CanonicalCoordinate center;
  var initialZoom = _defaultPickerZoom;
  final shouldLocateCurrentOnInitialize = initialLocation == null;
  if (initialLocation != null) {
    center = CanonicalCoordinate(
      latitude: initialLocation.latitude,
      longitude: initialLocation.longitude,
    );
    LocationPickerLogger.info(
      'initial_center_from_existing_location',
      context: {
        'latitude': center.latitude,
        'longitude': center.longitude,
        'zoom': initialZoom,
      },
    );
  } else {
    center = _fallbackPickerCenter;
    initialZoom = _fallbackPickerZoom;
    LocationPickerLogger.info(
      'initial_center_from_fallback_pending_gps',
      context: {
        'latitude': center.latitude,
        'longitude': center.longitude,
        'zoom': initialZoom,
      },
    );
  }

  final bundle = const LocationProviderBundleFactory().create(settings);
  final mapHostController = EmbeddedMapHostBridgeController();
  final controller = LocationPickerController(
    bundle: bundle,
    settings: settings,
    initialCenter: center,
    initialZoom: initialZoom,
    mapHostController: mapHostController,
    initialLocation: initialLocation,
    locateCurrentOnInitialize: shouldLocateCurrentOnInitialize,
  );

  LocationPickerLogger.info(
    'controller_created',
    context: {
      'provider': bundle.provider.name,
      'displayName': bundle.displayName,
      'initialLatitude': center.latitude,
      'initialLongitude': center.longitude,
      'initialZoom': initialZoom,
    },
  );

  unawaited(controller.initialize());
  if (!context.mounted) {
    LocationPickerLogger.warn('context_unmounted_before_presenting');
    controller.dispose();
    return null;
  }

  try {
    if (Platform.isWindows) {
      final result = await showDialog<MemoLocation>(
        context: context,
        builder: (_) => LocationPickerDialog(
          controller: controller,
          mapHostController: mapHostController,
          bundle: bundle,
        ),
      );
      LocationPickerLogger.info(
        'dialog_closed',
        context: {
          'saved': result != null,
          'latitude': result?.latitude,
          'longitude': result?.longitude,
          'placeholder': result?.placeholder,
        },
      );
      return result;
    }
    final result = await showModalBottomSheet<MemoLocation>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      enableDrag: false,
      builder: (_) => LocationPickerSheet(
        controller: controller,
        mapHostController: mapHostController,
        bundle: bundle,
      ),
    );
    LocationPickerLogger.info(
      'sheet_closed',
      context: {
        'saved': result != null,
        'latitude': result?.latitude,
        'longitude': result?.longitude,
        'placeholder': result?.placeholder,
      },
    );
    return result;
  } finally {
    LocationPickerLogger.info('controller_dispose_requested');
    controller.dispose();
  }
}

Future<LocationSettings> _resolveLocationSettings(WidgetRef ref) async {
  final current = ref.read(locationSettingsProvider);
  if (current.enabled) return current;
  final stored = await ref.read(locationSettingsRepositoryProvider).read();
  await ref
      .read(locationSettingsProvider.notifier)
      .setAll(stored, triggerSync: false);
  return stored;
}

Future<void> _showSettingsPrompt(BuildContext context, String message) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(dialogContext.t.strings.legacy.msg_select_location),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.t.strings.legacy.msg_cancel_2),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LocationSettingsScreen(),
                ),
              );
            },
            child: Text(dialogContext.t.strings.legacy.msg_open_settings),
          ),
        ],
      );
    },
  );
}
