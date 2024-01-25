import 'package:flutter/material.dart';
import 'transactions_list.dart';
import 'transactions.dart';

class TransactionsOverview extends StatelessWidget {
  const TransactionsOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Expanded(flex: 8, child: OverviewHeader()),
      Expanded(
        flex: 16,
        child: Column(
          children: [
            Row(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 16, 2, 4),
                child: Text("Recent Transactions",
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 16, 2, 4),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TransactionsPage(),
                      ),
                    );
                  },
                  child: const Text("See All"),
                ),
              ),
            ]),
            const Expanded(child: TransactionsList()),
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
