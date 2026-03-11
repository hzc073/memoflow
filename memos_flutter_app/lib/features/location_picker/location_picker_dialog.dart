import 'package:flutter/material.dart';

import '../../data/location/location_provider_bundle.dart';
import 'embedded_map_host.dart';
import 'location_picker_controller.dart';
import 'location_picker_sheet.dart';

class LocationPickerDialog extends StatelessWidget {
  const LocationPickerDialog({
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
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 900,
        height: 640,
        child: LocationPickerPanel(
          controller: controller,
          mapHostController: mapHostController,
          bundle: bundle,
          mapHostChild: mapHostChild,
        ),
      ),
    );
  }
}
