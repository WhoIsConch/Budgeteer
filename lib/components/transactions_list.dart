import 'package:budget/tools/api.dart';
import 'package:budget/tools/validators.dart';
import 'package:firebase_pagination/firebase_pagination.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/dialogs/manage_transaction.dart';
import 'package:budget/tools/enums.dart';

class TransactionsList extends StatefulWidget {
  const TransactionsList(
      {super.key,
      this.filters,
      this.sort,
      this.showActionButton = true,
      this.showBackground = true});

  final Set<TransactionFilter>? filters;
  final Sort? sort;
  final bool showActionButton;
  final bool showBackground;

  @override
  State<TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends State<TransactionsList> {
  bool isMultiselect = false;
  List<Transaction> selectedTransactions = [];

  bool get isFiltered => widget.filters != null || widget.sort != null;

  void showOptionsDialog(
      Transaction transaction, TransactionProvider transactionProvider) {
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
                setState(() {
                  transactionProvider.deleteTransaction(transaction);
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  ListTile tileFromTransaction(Transaction transaction, ThemeData theme,
      TransactionProvider transactionProvider) {
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
          onPressed: () => setState(() {
                isMultiselect = true;
                selectedTransactions.add(transaction);
              }));
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
      onLongPress: () => showOptionsDialog(transaction, transactionProvider),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => showOptionsDialog(transaction, transactionProvider),
      ),
      tileColor: theme.colorScheme.secondaryContainer,
      textColor: theme.colorScheme.onSecondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    );
  }

  Widget getList() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        // Return a stack with a listview in it so we can put that floating
        // action button at the bottom right
        List<Widget> stackChildren = [
          FirestorePagination(
            query: provider.getQuery(
                filters: widget.filters?.toList(), sort: widget.sort),
            limit: 20,
            isLive: true,
            bottomLoader: const Center(
                child: Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            )),
            onEmpty: Center(child: Text("No transactions")),
            itemBuilder: (context, snapshots, index) {
              final transaction = snapshots[index].data() as Transaction;

              return Card(
                child: tileFromTransaction(
                    transaction, Theme.of(context), provider),
              );
            },
          ),
        ];

        FloatingActionButton? actionButton;

        // if (isMultiselect) {
        //   actionButton = FloatingActionButton(
        //       child: const Icon(Icons.delete),
        //       onPressed: () {
        //         // Create a copy of the list, not a reference
        //         List<Transaction> removedTransactions = [
        //           ...selectedTransactions
        //         ];
        //         List<int> removedItemIndices = [];

        //         setState(() {
        //           selectedTransactions.clear();
        //           isMultiselect = false;

        //           for (int i = 0; i < removedTransactions.length; i++) {
        //             int index = transactions.indexOf(removedTransactions[i]);

        //             removedItemIndices.add(index);
        //             transactions.removeAt(index);
        //           }
        //         });

        //         bool undoPressed = false;

        //         scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
        //         scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
        //             behavior: SnackBarBehavior.floating,
        //             duration: const Duration(seconds: 3),
        //             action: SnackBarAction(
        //                 label: "Undo",
        //                 onPressed: () {
        //                   undoPressed = true;

        //                   setState(() {
        //                     for (int i = 0;
        //                         i < removedTransactions.length;
        //                         i++) {
        //                       transactions.insert(removedItemIndices[i],
        //                           removedTransactions[i]);
        //                     }
        //                   });
        //                 }),
        //             content: Text(
        //                 "${removedTransactions.length} ${removedTransactions.length == 1 ? "item" : "items"} deleted")));

        //         Timer.periodic(const Duration(seconds: 3, milliseconds: 250),
        //             (timer) async {
        //           if (undoPressed) {
        //             timer.cancel();
        //           } else {
        //             timer.cancel();
        //             scaffoldMessengerKey.currentState!
        //                 .hideCurrentSnackBar(); // This doesn't work if you move screens

        //             for (int i = 0; i < removedTransactions.length; i++) {
        //               provider.deleteTransaction(removedTransactions[i]);
        //             }
        //           }
        //         });
        //       });
        // } else if (widget.showActionButton) {
        //   actionButton = FloatingActionButton(
        //     shape: RoundedRectangleBorder(
        //       borderRadius: BorderRadius.circular(8.0),
        //     ),
        //     child: const Icon(Icons.add),
        //     onPressed: () => Navigator.push(
        //         context,
        //         MaterialPageRoute(
        //             builder: (context) => const ManageTransactionDialog(
        //                 mode: ObjectManageMode.add))),
        //   );
        // } else {
        //   actionButton = null;
        // }

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
      },
    );
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
