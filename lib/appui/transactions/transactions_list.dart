import 'package:budget/appui/components/status.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/utils/ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/appui/transactions/manage_transaction.dart';
import 'package:budget/utils/enums.dart';

class TransactionsList extends StatefulWidget {
  const TransactionsList({
    super.key,
    this.transactions,
    this.filters,
    this.sort,
    this.showActionButton = false,
    this.showBackground = true,
  });

  final bool showActionButton;
  final bool showBackground;
  final List<TransactionFilter>? filters;
  final List<Transaction>? transactions;
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
    ),
  );

  ListTile tileFromTransaction(Transaction transaction, ThemeData theme) {
    Widget leadingWidget;

    if (isMultiselect) {
      leadingWidget = SizedBox(
        height: 48,
        width: 48,
        child: Checkbox(
          value: selectedTransactions.contains(transaction),
          onChanged:
              (value) => setState(() {
                if (value != null && value) {
                  selectedTransactions.add(transaction);
                } else {
                  selectedTransactions.remove(transaction);

                  if (selectedTransactions.isEmpty) {
                    isMultiselect = false;
                  }
                }
              }),
        ),
      );
    } else {
      leadingWidget = IconButton(
        icon:
            (transaction.type == TransactionType.expense)
                ? const Icon(Icons.remove_circle)
                : const Icon(Icons.add_circle),
        onPressed: () {
          if (!widget.showActionButton) return;

          setState(() {
            isMultiselect = true;
            selectedTransactions.add(transaction);
          });
        },
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
      horizontalTitleGap: 4,
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 125),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: leadingWidget,
      ),
      title: Text(
        // Formats as "$500: Title of the Budget"
        "${"\$${formatAmount(transaction.amount)}"}: \"${transaction.title}\"",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(transaction.formatDate()),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      ManageTransactionPage(initialTransaction: transaction),
            ),
          ),
      onLongPress: () => showOptionsDialog(context, transaction),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => showOptionsDialog(context, transaction),
      ),
      tileColor: theme.colorScheme.secondaryContainer,
      textColor: theme.colorScheme.onSecondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );
  }

  Widget _getListview(List<Transaction> transactions) => ListView.separated(
    separatorBuilder: (_, _) => SizedBox(height: 8.0),
    itemCount: transactions.length,
    itemBuilder:
        (context, index) => Card(
          margin: EdgeInsets.zero,
          child: tileFromTransaction(transactions[index], Theme.of(context)),
        ),
  );

  Widget getList() {
    // Return a stack with a listview in it so we can put that floating
    // action button at the bottom right
    final db = context.read<AppDatabase>();
    List<Widget> stackChildren;

    if (widget.transactions == null) {
      // TODO: Not sure if Streams are lazy by default, but if they aren't
      // or this setup isn't, we should make it lazy.
      stackChildren = [
        StreamBuilder(
          // key: ValueKey(
          //     'tx_stream_${widget.filters.hashCode}_${widget.sort.hashCode}'),
          initialData: const [],
          stream: db.transactionDao.watchTransactionsPage(
            filters: widget.filters,
            sort: widget.sort,
            showArchived: true,
          ),
          builder: (context, snapshot) {
            List<Transaction>? transactionsToDisplay;
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
              listContent = ErrorInset('No transactions found');
            } else {
              listContent = _getListview(currentList);
            }

            return listContent;
          },
        ),
      ];
    } else {
      if (widget.transactions!.isEmpty) {
        stackChildren = [ErrorInset('No transactions found')];
      } else {
        stackChildren = [_getListview(widget.transactions!)];
      }
    }

    FloatingActionButton? actionButton;

    if (isMultiselect) {
      actionButton = FloatingActionButton(
        heroTag: 'list_fab',
        child: const Icon(size: 28, Icons.delete),
        onPressed: () {
          deletionManager.stageObjectsForDeletion<Transaction>(
            selectedTransactions.map((t) => t.id).toList(),
          );

          setState(() {
            selectedTransactions.clear();
            isMultiselect = false;
          });
        },
      );
    } else if (widget.showActionButton) {
      actionButton = FloatingActionButton(
        heroTag: 'list_fab',
        child: const Icon(size: 28, Icons.add),
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageTransactionPage(),
              ),
            ),
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

  @override
  void initState() {
    super.initState();

    deletionManager = DeletionManager(context);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showBackground) {
      return Card(
        color: getAdjustedColor(context, Theme.of(context).colorScheme.surface),
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
