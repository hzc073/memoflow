import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider<Object>? buildReaderFileImageProvider(String? path) {
  final normalized = path?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final file = File(normalized);
  if (!file.existsSync()) {
    return null;
  }
  return FileImage(file);
}
