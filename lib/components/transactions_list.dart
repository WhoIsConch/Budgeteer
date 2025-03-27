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
      this.categories,
      this.containsString,
      this.amountFilter});

  final DateTimeRange? dateRange;
  final TransactionType? type;
  final List<String>? categories;
  final String? containsString;
  final AmountFilter? amountFilter;

  @override
  State<TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends State<TransactionsList> {
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
                        builder: (context) => TransactionManageDialog(
                            mode: TransactionManageMode.edit,
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
    return ListTile(
      leading: (transaction.type == TransactionType.expense)
          ? const Icon(Icons.remove_circle)
          : const Icon(Icons.add_circle),
      title: Text("${transaction.formatAmount()} at ${transaction.title}"),
      subtitle: Text(transaction.formatDate()),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => TransactionManageDialog(
                  mode: TransactionManageMode.edit, transaction: transaction))),
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
        if (widget.categories != null && widget.categories!.isNotEmpty) {
          transactions = transactions.where((transaction) {
            return widget.categories!.contains(transaction.category);
          }).toList();
        }

        // If a string is specified, search the description and the title for
        // that string and return results containing it
        if (widget.containsString != null &&
            widget.containsString!.isNotEmpty) {
          transactions = transactions.where((transaction) {
            return transaction.title.contains(widget.containsString!) ||
                transaction.notes!.contains(widget.containsString!);
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

        print(widget.containsString);
        print(widget.categories);

        // Sort transactions by date, most recent first
        transactions.sort((a, b) => b.date.compareTo(a.date));

        if (transactions.isEmpty) {
          // If there are no transactions, return a message saying so.
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                            builder: (context) => const TransactionManageDialog(
                                mode: TransactionManageMode.add))),
                  )
                ]),
          );
        }

        // Return a stack with a listview in it so we can put that floating
        // action button at the bottom right
        return Stack(children: [
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                child: const Icon(Icons.add),
                // onPressed: () {
                //   showDialog(
                //       context: context,
                //       builder: (context) => const TransactionManageDialog(
                //           mode: TransactionManageMode.add));
                // },
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TransactionManageDialog(
                            mode: TransactionManageMode.add))),
              ),
            ),
          )
        ]);
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
