import 'dart:async';

import 'package:budget/tools/api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/components/transaction_form.dart';
import 'package:budget/tools/enums.dart';

class TransactionsList extends StatefulWidget {
  const TransactionsList(
      {super.key,
      this.dateRange,
      this.type,
      this.searchCategories,
      this.searchString,
      this.amountFilter,
      this.showActionButton = true});

  final DateTimeRange? dateRange;
  final TransactionType? type;
  final List<Category>? searchCategories;
  final String? searchString;
  final AmountFilter? amountFilter;
  final bool showActionButton;

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
                        builder: (context) => TransactionManageScreen(
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
        height: 24,
        width: 24,
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
      leadingWidget = GestureDetector(
          child: (transaction.type == TransactionType.expense)
              ? const Icon(Icons.remove_circle)
              : const Icon(Icons.add_circle),
          onTap: () => setState(() {
                isMultiselect = true;
                selectedTransactions.add(transaction);
              }));
    }

    return ListTile(
      leading: leadingWidget,
      title: Text("${transaction.formatAmount()} at ${transaction.title}"),
      subtitle: Text(transaction.formatDate()),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => TransactionManageScreen(
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

        // If a transaction type is specified, filter the transactions by that
        if (widget.type == TransactionType.expense) {
          transactions = transactions.where((transaction) {
            return transaction.type == TransactionType.expense;
          }).toList();
        } else if (widget.type == TransactionType.income) {
          transactions = transactions.where((transaction) {
            return transaction.type == TransactionType.income;
          }).toList();
        }

        // If there is a specified date range, filter the transactions by that
        if (widget.dateRange != null) {
          transactions = transactions.where((transaction) {
            // Adding and subtracting a day to the start and end of the date
            // because "After" and "Before" are not inclusive of the start and
            // end dates
            return transaction.date.isAfter(widget.dateRange!.start
                    .subtract(const Duration(days: 1))) &&
                transaction.date.isBefore(
                    widget.dateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }

        // If there are categories specified, filter the transactions by those
        if (widget.searchCategories != null &&
            widget.searchCategories!.isNotEmpty) {
          transactions = transactions.where((transaction) {
            return widget.searchCategories!.contains(transaction.category);
          }).toList();
        }

        // If a string is specified, search the description and the title for
        // that string and return results containing it
        if (widget.searchString != null && widget.searchString!.isNotEmpty) {
          transactions = transactions.where((transaction) {
            return transaction.title.contains(widget.searchString!) ||
                transaction.notes!.contains(widget.searchString!);
          }).toList();
        }

        if (widget.amountFilter != null && widget.amountFilter!.isPopulated()) {
          transactions = transactions.where((transaction) {
            switch (widget.amountFilter!.type) {
              case AmountFilterType.greaterThan:
                return transaction.amount > widget.amountFilter!.value!;
              case AmountFilterType.lessThan:
                return transaction.amount < widget.amountFilter!.value!;
              case _:
                return transaction.amount == widget.amountFilter!.value!;
            }
          }).toList();
        }

        print(widget.searchString);
        print(widget.searchCategories);

        // Sort transactions by date, most recent first
        transactions.sort((a, b) => b.date.compareTo(a.date));

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
                            builder: (context) => const TransactionManageScreen(
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
            itemBuilder: (context, index) {
              Transaction transaction = transactions[index];
              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: Card(
                  child: tileFromTransaction(
                      transaction, Theme.of(context), transactionProvider),
                ),
              );
            },
          ),
        ];

        FloatingActionButton actionButton;

        if (widget.showActionButton) {
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

                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      setState(() {
                        for (int i = 0; i < removedTransactions.length; i++) {
                          transactionProvider
                              .removeTransaction(removedTransactions[i]);
                        }
                      });
                    }
                  });
                });
          } else {
            actionButton = FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TransactionManageScreen(
                          mode: ObjectManageMode.add))),
            );
          }
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
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: getList(),
    );
  }
}
