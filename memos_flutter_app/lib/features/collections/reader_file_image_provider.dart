import 'package:flutter/widgets.dart';

import 'reader_file_image_provider_stub.dart'
    if (dart.library.io) 'reader_file_image_provider_io.dart' as impl;

ImageProvider<Object>? buildReaderFileImageProvider(String? path) {
  return impl.buildReaderFileImageProvider(path);
}
