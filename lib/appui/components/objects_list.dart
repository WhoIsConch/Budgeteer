import 'package:budget/appui/components/status.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/appui/transactions/manage_transaction.dart';

class ObjectsList<T extends Tileable<T>> extends StatefulWidget {
  const ObjectsList({
    super.key,
    this.objects,
    this.filters,
    this.sort,
    this.showActionButton = false,
    this.showBackground = true,
  });

  final bool showActionButton;
  final bool showBackground;
  final List<Filter>? filters;
  final List<T>? objects;
  final Sort? sort;

  @override
  State<ObjectsList> createState() => _ObjectsListState<T>();
}

class _ObjectsListState<T extends Tileable<T>> extends State<ObjectsList<T>> {
  bool isMultiselect = false;
  List<T> selectedObjects = [];
  late final DeletionManager deletionManager;

  List<T>? _lastSuccessfulData;

  // Just in case I need this in the future
  Widget get bottomLoader => const Center(
    child: Padding(
      padding: EdgeInsets.all(8.0),
      child: LinearProgressIndicator(),
    ),
  );

  Widget _getListview(List<T> objects) => ListView.separated(
    separatorBuilder: (_, _) => SizedBox(height: 8.0),
    itemCount: objects.length,
    itemBuilder:
        (context, index) => Card(
          margin: EdgeInsets.zero,
          child: objects[index].getTile(
            context,
            isMultiselect: isMultiselect,
            isSelected: selectedObjects.contains(objects[index]),
          ),
        ),
  );

  Widget getList() {
    // Return a stack with a listview in it so we can put that floating
    // action button at the bottom right
    List<Widget> stackChildren;

    if (widget.objects == null) {
      // TODO: Not sure if Streams are lazy by default, but if they aren't
      // or this setup isn't, we should make it lazy.
      stackChildren = [
        StreamBuilder<List<T>>(
          // key: ValueKey(
          //     'tx_stream_${widget.filters.hashCode}_${widget.sort.hashCode}'),
          initialData: const [],
          stream: _getStream(),
          builder: (context, snapshot) {
            List<T>? objectsToDisplay;
            bool showLoadingIndicator = false;

            if (snapshot.hasError) {
              return const Center(
                child: Text('Something went wrong. Please try again'),
              );
            }

            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                if (_lastSuccessfulData != null) {
                  objectsToDisplay = _lastSuccessfulData;
                  showLoadingIndicator = true;
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
                break;
              case ConnectionState.active:
              case ConnectionState.done:
                _lastSuccessfulData = snapshot.data ?? [];
                objectsToDisplay = _lastSuccessfulData;

                showLoadingIndicator = false;
                break;
            }

            final currentList = objectsToDisplay ?? [];

            Widget listContent;
            if (currentList.isEmpty && !showLoadingIndicator) {
              listContent = ErrorInset.noTransactions;
            } else {
              listContent = _getListview(currentList);
            }

            return listContent;
          },
        ),
      ];
    } else {
      if (widget.objects!.isEmpty) {
        stackChildren = [ErrorInset.noTransactions];
      } else {
        stackChildren = [_getListview(widget.objects!)];
      }
    }

    FloatingActionButton? actionButton;

    if (isMultiselect) {
      actionButton = FloatingActionButton(
        heroTag: 'list_fab',
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        onPressed: _onDelete,
        child: const Icon(size: 28, Icons.delete),
      );
    } else if (widget.showActionButton) {
      actionButton = FloatingActionButton(
        heroTag: 'list_fab',
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        onPressed: _onCreate,
        child: const Icon(size: 28, Icons.add),
      );
    } else {
      actionButton = null;
    }

    if (actionButton != null) {
      stackChildren.add(
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Align(alignment: Alignment.bottomRight, child: actionButton),
        ),
      );
    }

    return Stack(children: stackChildren);
  }

  void _onDelete() {
    final deletionManager = DeletionManager(context);

    switch (T) {
      case TransactionTileableAdapter:
        deletionManager.stageObjectsForDeletion<Transaction>(
          selectedObjects.map((t) => t.id).toList(),
        );

        setState(() {
          selectedObjects.clear();
          isMultiselect = false;
        });
        break;
      // case GoalTileableAdapter:
      //
    }
  }

  void _onCreate() {
    switch (T) {
      case TransactionTileableAdapter:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ManageTransactionPage(),
          ),
        );
        break;
    }
  }

  Stream<List<T>>? _getStream() {
    final db = context.read<AppDatabase>();

    switch (T) {
      case TransactionTileableAdapter:
        final Stream<List<Transaction>> sourceStream = db.transactionDao
            .watchTransactionsPage(
              filters: widget.filters,
              sort: widget.sort,
              showArchived: true,
            );
        final Stream<List<TransactionTileableAdapter>> mappedStream =
            sourceStream.map(
              (e) =>
                  e
                      .map(
                        (t) => TransactionTileableAdapter(
                          t,
                          onMultiselect:
                              (value, object) => setState(() {
                                if (value != null && value) {
                                  isMultiselect = true;
                                  selectedObjects.add(object as T);
                                } else {
                                  selectedObjects.remove(object);

                                  if (selectedObjects.isEmpty) {
                                    isMultiselect = false;
                                  }
                                }
                              }),
                        ),
                      )
                      .toList(),
            );

        return mappedStream as Stream<List<T>>;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    deletionManager = DeletionManager(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showBackground) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(padding: const EdgeInsets.all(8.0), child: getList()),
      );
    } else {
      return getList();
    }
  }
}
