import 'package:budget/services/app_database.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/views/panels/manage_transaction.dart';
import 'package:budget/utils/enums.dart';

class TransactionsList extends StatefulWidget {
  const TransactionsList(
      {super.key,
      this.filters,
      this.sort,
      this.showActionButton = false,
      this.showBackground = true});

  final bool showActionButton;
  final bool showBackground;
  final List<TransactionFilter>? filters;
  final Sort? sort;

  @override
  State<TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends State<TransactionsList> {
  bool isMultiselect = false;
  List<Transaction> selectedTransactions = [];
  late final DeletionManager deletionManager;

  List<Transaction>? _lastSuccessfulData;

  // Just in case I need this in the future
  Widget get bottomLoader => const Center(
          child: Padding(
        padding: EdgeInsets.all(8.0),
        child: LinearProgressIndicator(),
      ));

  void showOptionsDialog(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ManageTransactionDialog(
                            mode: ObjectManageMode.edit,
                            transaction: transaction)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text("Delete"),
              onTap: () {
                deletionManager
                    .stageObjectsForDeletion<Transaction>([transaction.id]);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  ListTile tileFromTransaction(Transaction transaction, ThemeData theme) {
    // Dart formats all of this code horribly, but I can't really change it.

    Widget leadingWidget;

    if (isMultiselect) {
      leadingWidget = SizedBox(
        height: 48,
        width: 48,
        child: Checkbox(
            value: selectedTransactions.contains(transaction),
            onChanged: (value) => setState(() {
                  if (value != null && value) {
                    selectedTransactions.add(transaction);
                  } else {
                    selectedTransactions.remove(transaction);

                    if (selectedTransactions.isEmpty) {
                      isMultiselect = false;
                    }
                  }
                })),
      );
    } else {
      leadingWidget = IconButton(
          icon: (transaction.type == TransactionType.expense)
              ? const Icon(
                  Icons.remove_circle,
                )
              : const Icon(Icons.add_circle),
          onPressed: () {
            if (!widget.showActionButton) return;

            setState(() {
              isMultiselect = true;
              selectedTransactions.add(transaction);
            });
          });
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
      horizontalTitleGap: 4,
      leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 125),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: leadingWidget),
      title: Text(
          // Formats as "$500: Title of the Budget"
          "${"\$${formatAmount(transaction.amount)}"}: \"${transaction.title}\"",
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(transaction.formatDate()),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ManageTransactionDialog(
                  mode: ObjectManageMode.edit, transaction: transaction))),
      onLongPress: () => showOptionsDialog(transaction),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => showOptionsDialog(transaction),
      ),
      tileColor: theme.colorScheme.secondaryContainer,
      textColor: theme.colorScheme.onSecondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    );
  }

  Widget getList() {
    // Return a stack with a listview in it so we can put that floating
    // action button at the bottom right
    final dao = context.read<TransactionDao>();
    List<Widget> stackChildren = [
      // TODO: Not sure if Streams are lazy by default, but if they aren't
      // or this setup isn't, we should make it lazy.
      StreamBuilder(
          // key: ValueKey(
          //     'tx_stream_${widget.filters.hashCode}_${widget.sort.hashCode}'),
          initialData: const [],
          stream: dao.watchTransactionsPage(
            filters: widget.filters,
            sort: widget.sort,
          ),
          builder: (context, snapshot) {
            List<Transaction>? transactionsToDisplay;
            bool showLoadingIndicator = false;

            if (snapshot.hasError) {
              return Center(
                  child: Text("Something went wrong. Please try again"));
            }

            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                if (_lastSuccessfulData != null) {
                  transactionsToDisplay = _lastSuccessfulData;
                  showLoadingIndicator = true;
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
                break;
              case ConnectionState.active:
              case ConnectionState.done:
                _lastSuccessfulData = snapshot.data as List<Transaction>? ?? [];
                transactionsToDisplay = _lastSuccessfulData;

                showLoadingIndicator = false;
                break;
            }

            final currentList = transactionsToDisplay ?? [];

            Widget listContent;
            if (currentList.isEmpty && !showLoadingIndicator) {
              listContent = Center(
                  child: Text("No transactions found.",
                      style: Theme.of(context).textTheme.headlineSmall));
            } else {
              listContent = ListView.builder(
                  itemCount: currentList.length,
                  itemBuilder: (context, index) => Card(
                        child: tileFromTransaction(
                            currentList[index], Theme.of(context)),
                      ));
            }

            return listContent;
          }),
    ];

    FloatingActionButton? actionButton;

    if (isMultiselect) {
      actionButton = FloatingActionButton(
          child: const Icon(size: 28, Icons.delete),
          onPressed: () {
            deletionManager.stageObjectsForDeletion<Transaction>(
                selectedTransactions.map((t) => t.id).toList());

            setState(() {
              selectedTransactions.clear();
              isMultiselect = false;
            });
          });
    } else if (widget.showActionButton) {
      actionButton = FloatingActionButton(
        child: const Icon(size: 28, Icons.add),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const ManageTransactionDialog(mode: ObjectManageMode.add))),
      );
    } else {
      actionButton = null;
    }

    if (actionButton != null) {
      stackChildren.add(Padding(
        padding: const EdgeInsets.all(16.0),
        child: Align(
          alignment: Alignment.bottomRight,
          child: actionButton,
        ),
      ));
    }

    return Stack(children: stackChildren);
  }

  @override
  void initState() {
    super.initState();

    deletionManager = context.read<DeletionManager>();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showBackground) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: getList(),
      );
    } else {
      return getList();
    }
  }
}
