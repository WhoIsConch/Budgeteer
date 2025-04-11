import 'dart:async';

import 'package:budget/tools/api.dart';
import 'package:budget/tools/validators.dart';
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
                  transactionProvider.removeTransaction(transaction);
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
      builder: (context, transactionProvider, child) {
        List<Transaction> transactions = transactionProvider.transactions;

        if (widget.filters != null) {
          for (TransactionFilter filter in widget.filters!) {
            switch (filter.filterType) {
              case FilterType.type:
                // If a transaction type is specified, filter the transactions by that
                if (filter.value == TransactionType.expense) {
                  transactions = transactions.where((transaction) {
                    return transaction.type == TransactionType.expense;
                  }).toList();
                } else if (filter.value == TransactionType.income) {
                  transactions = transactions.where((transaction) {
                    return transaction.type == TransactionType.income;
                  }).toList();
                }
                break;
              case FilterType.dateRange:
                transactions = transactions.where((transaction) {
                  // Adding and subtracting a day to the start and end of the date
                  // because "After" and "Before" are not inclusive of the start and
                  // end dates
                  return transaction.date.isInRange(filter.value);
                }).toList();
                break;
              case FilterType.category:
                transactions = transactions.where((transaction) {
                  return filter.value!
                      .where((e) => e.name == transaction.category)
                      .isNotEmpty;
                }).toList();
                break;
              case FilterType.string:
                transactions = transactions.where((transaction) {
                  return transaction.title
                          .toLowerCase()
                          .contains(filter.value.toLowerCase()) ||
                      (transaction.notes != null &&
                          transaction.notes!
                              .toLowerCase()
                              .contains(filter.value.toLowerCase()));
                }).toList();
                break;
              case FilterType.amount:
                transactions = transactions.where((transaction) {
                  switch (filter.info) {
                    case AmountFilterType.greaterThan:
                      return transaction.amount > filter.value;
                    case AmountFilterType.lessThan:
                      return transaction.amount < filter.value;
                    case _:
                      return transaction.amount == filter.value;
                  }
                }).toList();
                break;
            }
          }
        }

        // Sort transactions by date, most recent first
        Sort sort =
            widget.sort ?? const Sort(SortType.date, SortOrder.descending);

        switch (sort.sortType) {
          case SortType.date:
            if (sort.sortOrder == SortOrder.descending) {
              transactions.sort((a, b) => b.date.compareTo(a.date));
            } else {
              transactions.sort((a, b) => -b.date.compareTo(a.date));
            }
            break;
          case SortType.name:
            if (sort.sortOrder == SortOrder.descending) {
              transactions.sort((a, b) =>
                  -b.title.toLowerCase().compareTo(a.title.toLowerCase()));
            } else {
              transactions.sort((a, b) =>
                  b.title.toLowerCase().compareTo(a.title.toLowerCase()));
            }
            break;
          case SortType.amount:
            if (sort.sortOrder == SortOrder.descending) {
              transactions.sort((a, b) => b.amount.compareTo(a.amount));
            } else {
              transactions.sort((a, b) => -b.amount.compareTo(a.amount));
            }
        }

        if (transactions.isEmpty) {
          // If there are no transactions, return a message saying so.
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                // crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Makes the card that holds the transactions fill up all available horizontal space
                  const SizedBox(height: 0, child: SizedBox.expand()),
                  const Text("No transactions.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20.0,
                      )),
                  ElevatedButton(
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Text("Add a transaction",
                          style: TextStyle(
                            fontSize: 24.0,
                          )),
                    ),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ManageTransactionDialog(
                                mode: ObjectManageMode.add))),
                  )
                ]),
          );
        }

        // Return a stack with a listview in it so we can put that floating
        // action button at the bottom right

        List<Widget> stackChildren = [
          ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (BuildContext context, int index) {
              Transaction transaction = transactions[index];
              return Card(
                child: tileFromTransaction(
                    transaction, Theme.of(context), transactionProvider),
              );
            },
          ),
        ];

        FloatingActionButton? actionButton;

        if (isMultiselect) {
          actionButton = FloatingActionButton(
              child: const Icon(Icons.delete),
              onPressed: () {
                // Create a copy of the list, not a reference
                List<Transaction> removedTransactions = [
                  ...selectedTransactions
                ];
                List<int> removedItemIndices = [];

                setState(() {
                  selectedTransactions.clear();
                  isMultiselect = false;

                  for (int i = 0; i < removedTransactions.length; i++) {
                    int index = transactions.indexOf(removedTransactions[i]);

                    removedItemIndices.add(index);
                    transactions.removeAt(index);
                  }
                });

                bool undoPressed = false;

                scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
                scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                    action: SnackBarAction(
                        label: "Undo",
                        onPressed: () {
                          undoPressed = true;

                          setState(() {
                            for (int i = 0;
                                i < removedTransactions.length;
                                i++) {
                              transactions.insert(removedItemIndices[i],
                                  removedTransactions[i]);
                            }
                          });
                        }),
                    content: Text(
                        "${removedTransactions.length} ${removedTransactions.length == 1 ? "item" : "items"} deleted")));

                Timer.periodic(const Duration(seconds: 3, milliseconds: 250),
                    (timer) async {
                  if (undoPressed) {
                    timer.cancel();
                  } else {
                    timer.cancel();
                    scaffoldMessengerKey.currentState!
                        .hideCurrentSnackBar(); // This doesn't work if you move screens

                    for (int i = 0; i < removedTransactions.length; i++) {
                      transactionProvider
                          .removeTransaction(removedTransactions[i]);
                    }
                  }
                });
              });
        } else if (widget.showActionButton) {
          actionButton = FloatingActionButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Icon(Icons.add),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ManageTransactionDialog(
                        mode: ObjectManageMode.add))),
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
