import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_flutter_app/data/ai/ai_analysis_models.dart';

void main() {
  test('decodeFloat32VectorBlob decodes misaligned blob views safely', () {
    final source = Float32List.fromList(<double>[0.25, -1.5, 9.0]);
    final sourceBytes = source.buffer.asUint8List(
      source.offsetInBytes,
      source.lengthInBytes,
    );
    final padded = Uint8List(sourceBytes.length + 1)
      ..[0] = 7
      ..setRange(1, sourceBytes.length + 1, sourceBytes);
    final misalignedBlob = Uint8List.sublistView(padded, 1);

    expect(
      misalignedBlob.offsetInBytes % Float32List.bytesPerElement,
      isNonZero,
    );

    final decoded = decodeFloat32VectorBlob(misalignedBlob);

    expect(decoded, isNotNull);
    expect(decoded, isA<Float32List>());
    expect(decoded!.toList(), orderedEquals(source.toList()));
  });

  test('AiEmbeddingRecord.fromRow drops malformed vector blobs', () {
    final record = AiEmbeddingRecord.fromRow(<String, dynamic>{
      'id': 1,
      'chunk_id': 2,
      'base_url': 'https://example.com',
      'model': 'text-embedding-3-small',
      'dimensions': 1,
      'status': 'ready',
      'vector_blob': Uint8List.fromList(<int>[1, 2, 3]),
      'error_text': null,
    });

    expect(record.vector, isNull);
  });
}
