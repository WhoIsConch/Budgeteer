import 'package:flutter/material.dart';
import 'home_card.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeCard(title: "Amount Spent Today", content: "\$200"),
        TransactionList(),
    ]);
  }
}

class TransactionList extends StatelessWidget {
  const TransactionList({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Text("Transactions", style: Theme.of(context).textTheme.titleLarge),
          ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.monetization_on),
                title: Text("Transaction $index"),
                subtitle: Text("Transaction $index"),
                trailing: const Icon(Icons.more_vert),
              );
            },
          ),
        ],
      ),
    );
  }
}
