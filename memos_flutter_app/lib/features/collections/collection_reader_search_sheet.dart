import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/local_memo.dart';
import '../../i18n/strings.g.dart';
import 'collection_reader_panel.dart';
import 'collection_reader_utils.dart';

typedef CollectionReaderSearchSelect =
    FutureOr<void> Function(CollectionReaderSearchResult result, String query);

class CollectionReaderSearchSheet extends StatefulWidget {
  const CollectionReaderSearchSheet({
    super.key,
    required this.items,
    required this.onSelect,
  });

  final List<LocalMemo> items;
  final CollectionReaderSearchSelect onSelect;

  @override
  State<CollectionReaderSearchSheet> createState() =>
      _CollectionReaderSearchSheetState();
}

class _CollectionReaderSearchSheetState
    extends State<CollectionReaderSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'collectionReaderSearch');
  Timer? _debounce;
  List<CollectionReaderSearchResult> _results =
      const <CollectionReaderSearchResult>[];
  bool _loading = false;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _results = const <CollectionReaderSearchResult>[];
      });
      return;
    }
    setState(() => _loading = true);
    final token = ++_searchToken;
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      final results = widget.items.length < 24
          ? buildCollectionReaderSearchResults(
              items: widget.items,
              query: query,
            )
          : await buildCollectionReaderSearchResultsAsync(
              items: widget.items,
              query: query,
            );
      if (!mounted || token != _searchToken) {
        return;
      }
      setState(() {
        _loading = false;
        _results = results;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final isEmptyQuery = query.isEmpty;
    return CollectionReaderSheetFrame(
      title: context.t.strings.collections.searchInsideCollection,
      expandChild: true,
      child: Column(
        children: [
          CollectionReaderPanelCard(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onChanged: _handleQueryChanged,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText:
                          context.t.strings.collections.searchInsideCollection,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (!isEmptyQuery) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: context.t.strings.collections.clearSearch,
                    onPressed: () {
                      _controller.clear();
                      _handleQueryChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CollectionReaderPanelCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Builder(
                builder: (context) {
                  if (_loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (isEmptyQuery) {
                    return Center(
                      child: Text(
                        context.t.strings.legacy.msg_search_memo_content,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (_results.isEmpty) {
                    return Center(
                      child: Text(
                        context.t.strings.collections.searchNoResultsTitle(
                          query: query,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '#${result.memoIndex + 1} · ${result.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          result.excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: CircleAvatar(
                          radius: 14,
                          child: Text(
                            '${result.matchCount}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        onTap: () async {
                          await widget.onSelect(result, query);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
