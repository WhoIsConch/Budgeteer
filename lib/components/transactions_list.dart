import 'package:budget/tools/api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/components/transaction_form.dart';
import 'package:budget/tools/enums.dart';

class TransactionsList extends StatefulWidget {
  const TransactionsList({super.key, this.dateRange, this.type});

  final DateTimeRange? dateRange;
  final TransactionType? type;

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
                showDialog(
                    context: context,
                    builder: (context) => TransactionManageDialog(
                        mode: TransactionManageMode.edit,
                        transaction: transaction));
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
    return ListTile(
      leading: const Icon(Icons.monetization_on),
      title: Text("${transaction.formatAmount()} at ${transaction.title}"),
      subtitle: Text(transaction.formatDate()),
      onTap: () => showDialog(
          context: context,
          builder: (context) => TransactionManageDialog(
              mode: TransactionManageMode.edit, transaction: transaction)),
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

        if (widget.type == TransactionType.expense) {
          transactions = transactions.where((transaction) {
            return transaction.type == TransactionType.expense;
          }).toList();
        } else if (widget.type == TransactionType.income) {
          transactions = transactions.where((transaction) {
            return transaction.type == TransactionType.income;
          }).toList();
        }

        if (widget.dateRange != null) {
          transactions = transactions.where((transaction) {
            return transaction.date.isAfter(widget.dateRange!.start
                    .subtract(const Duration(days: 1))) &&
                transaction.date.isBefore(
                    widget.dateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }

        // Sort transactions by date, most recent first
        transactions.sort((a, b) => b.date.compareTo(a.date));

        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            try {
              Transaction transaction = transactions[index];
              return Padding(
                padding: const EdgeInsets.all(4.0),
                child: Card(
                  child: tileFromTransaction(
                      transaction, Theme.of(context), transactionProvider),
                ),
              );
            } catch (e) {
              return const SizedBox.shrink();
            }
          },
        );
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
