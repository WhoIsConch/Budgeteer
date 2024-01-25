import 'package:budget/tools/api.dart';
import 'package:flutter/material.dart';

class TransactionsList extends StatefulWidget {
  const TransactionsList({super.key});

  @override
  State<TransactionsList> createState() => _TransactionsListState();
}

class _TransactionsListState extends State<TransactionsList> {
  late List<Transaction> transactions;

  @override
  void initState() {
    super.initState();
    transactions = getMockTransactions();
  }

  ListTile tileFromTransaction(Transaction transaction, ThemeData theme) {
    return ListTile(
      leading: const Icon(Icons.monetization_on),
      title: Text("${transaction.formatAmount()} at ${transaction.title}"),
      subtitle: Text(transaction.formatDate()),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () {
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
                      Navigator.pop(context); // TODO: Navigate to edit page
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text("Delete"),
                    onTap: () {
                      setState(() {
                        transactions.remove(transaction);
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
      tileColor: theme.colorScheme.secondaryContainer,
      textColor: theme.colorScheme.onSecondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
    );
  }

  ListView getList() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        try {
          Transaction transaction = transactions[index];
          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Card(
              child: tileFromTransaction(transaction, Theme.of(context)),
            ),
          );
        } catch (e) {
          return const SizedBox.shrink();
        }
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
