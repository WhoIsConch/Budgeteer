import 'package:flutter/material.dart';
import 'api.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(flex: 8, child: OverviewHeader()),
      Expanded(
        flex: 16,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 2, 4),
              child: Text("Recent Transactions",
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            const Expanded(child: TransactionList()),
          ],
        ),
      ),
    ]);
  }
}

class OverviewHeader extends StatelessWidget {
  /* 
  OverviewHeader is a section at the top of the page with a 2x2 grid of 
  cards that hold information about the user's spending. These cards are:
  - Spending Today
  - Spending This Week
  - Spending This Month
  - Spending This Year
  */
  const OverviewHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // When making this stateful, make sure the numbers update when the user
    // adds a new transaction. Also make sure the numbers do not overflow,
    // possibly replace some if they get too big (eg. $1000.00 > $1.0k)
    return const Card(
        child: Column(children: [
      Expanded(
        child: Row(
          children: [
            Expanded(
              child: OverviewCard(
                title: "Spent Today",
                content: "\$0.00",
              ),
            ),
            Expanded(
              child: OverviewCard(
                title: "Spent This Week",
                content: "\$0.00",
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: Row(
          children: [
            Expanded(
              child: OverviewCard(
                title: "Spent This Month",
                content: "\$0.00",
              ),
            ),
            Expanded(
              child: OverviewCard(
                title: "Spent This Year",
                content: "\$0.00",
              ),
            ),
          ],
        ),
      )
    ]));
  }
}

class OverviewCard extends StatelessWidget {
  final String title;
  final String content;

  const OverviewCard({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                  textAlign: TextAlign.center,
                  title,
                  style: theme.textTheme.titleSmall),
              Text(
                  textAlign: TextAlign.center,
                  content,
                  style: theme.textTheme.headlineLarge),
            ]),
      ),
    );
  }
}

class TransactionList extends StatefulWidget {
  const TransactionList({super.key});

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
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

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          try {
            Transaction transaction = transactions[index];
            return Padding(
              padding: const EdgeInsets.all(4.0),
              child: Card(
                child: tileFromTransaction(transaction, theme),
              ),
            );
          } catch (e) {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
