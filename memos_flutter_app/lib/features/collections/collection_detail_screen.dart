import 'package:flutter/material.dart';

import 'collection_reader_screen.dart';

class CollectionDetailScreen extends StatelessWidget {
  const CollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context) {
    return CollectionReaderScreen(collectionId: collectionId);
  }
}
