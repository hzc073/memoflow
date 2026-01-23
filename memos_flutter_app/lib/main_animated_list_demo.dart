import 'package:flutter/material.dart';

void main() {
  runApp(const MemoFlowAnimatedListDemo());
}

class MemoFlowAnimatedListDemo extends StatelessWidget {
  const MemoFlowAnimatedListDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MemoFlow AnimatedList Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFC0564D)),
      home: const AnimatedNotesPage(),
    );
  }
}

class Note {
  Note({required this.id, required this.title, required this.body});

  final String id;
  final String title;
  final String body;
}

class AnimatedNotesPage extends StatefulWidget {
  const AnimatedNotesPage({super.key});

  @override
  State<AnimatedNotesPage> createState() => _AnimatedNotesPageState();
}

class _AnimatedNotesPageState extends State<AnimatedNotesPage> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<Note> _notes = List.generate(
    8,
    (i) => Note(
      id: 'note_$i',
      title: 'Memo ${i + 1}',
      body: 'This is a sample memo content for item ${i + 1}.',
    ),
  );

  void _removeAt(int index) {
    if (index < 0 || index >= _notes.length) return;
    final removed = _notes.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildItem(
        note: removed,
        animation: animation,
        removing: true,
      ),
      duration: const Duration(milliseconds: 380),
    );
    setState(() {});
  }

  Widget _buildItem({
    required Note note,
    required Animation<double> animation,
    VoidCallback? onDelete,
    bool removing = false,
  }) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    return SizeTransition(
      sizeFactor: curved,
      axis: Axis.vertical,
      axisAlignment: 0.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            title: Text(note.title),
            subtitle: Text(note.body),
            trailing: removing
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animated Notes')),
      body: AnimatedList(
        key: _listKey,
        initialItemCount: _notes.length,
        itemBuilder: (context, index, animation) {
          final note = _notes[index];
          return _buildItem(
            note: note,
            animation: animation,
            onDelete: () => _removeAt(index),
          );
        },
      ),
    );
  }
}
