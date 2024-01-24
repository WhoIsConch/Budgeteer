import 'package:flutter/material.dart';
import 'home_card.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, 
      children: [
        HomeCard(title: "Amount Spent Today", content: "\$200"),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 16, 2, 4),
                child: Text("Transactions", style: Theme.of(context).textTheme.headlineMedium),
              ),
              Expanded(child: TransactionList()),
            ],
          ),
        ),
    ]);
  }
}

class TransactionList extends StatelessWidget {
  const TransactionList({super.key});

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
          return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.monetization_on),
                title: Text("Transaction $index"),
                subtitle: Text("Transaction $index"),
                trailing: const Icon(Icons.more_vert),
                tileColor: theme.colorScheme.secondaryContainer,
                textColor: theme.colorScheme.onSecondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
