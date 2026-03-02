import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'note_input_controller.dart' show NoteInputPendingAttachment;
import 'note_input_controller.dart';

final noteInputControllerProvider = Provider<NoteInputController>((ref) {
  return NoteInputController(ref);
});
