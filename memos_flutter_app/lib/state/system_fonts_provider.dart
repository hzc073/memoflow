import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/system_fonts.dart';

final systemFontsProvider = FutureProvider<List<SystemFontInfo>>((ref) async {
  return SystemFonts.listFonts();
});
