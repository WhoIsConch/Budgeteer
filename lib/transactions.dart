import 'package:flutter/material.dart';
import 'home_card.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(children: const [
      SizedBox(
          height: 200,
          child: HomeCard(title: "Amount Spent Today", content: "\$200")),
    ]);
  }
}
