import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/layouts/transactions.dart';

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
                padding: const EdgeInsets.fromLTRB(4, 16, 2, 4),
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
    return Card(
        child: Column(children: [
      Expanded(
        child: Row(
          children: [
            Expanded(
              child: OverviewCard(
                title: "Spent Today",
                content: "\$0.00",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionsPage(),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: OverviewCard(
                  title: "Spent This Week",
                  content: "\$0.00",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) {
                        // TODO: Setting that changes the start of the week
                        DateTime now = DateTime.now();
                        DateTime startOfWeek = now.subtract(
                          Duration(days: now.weekday - 1),
                        );

                        return TransactionsPage(
                          startingDateRange: DateTimeRange(
                            start: startOfWeek,
                            end: now,
                          ),
                        );
                      }),
                    );
                  }),
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      DateTime now = DateTime.now();
                      DateTime startOfMonth = DateTime(now.year, now.month);

                      return TransactionsPage(
                        startingDateRange: DateTimeRange(
                          start: startOfMonth,
                          end: now,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
            Expanded(
              child: OverviewCard(
                title: "Spent This Year",
                content: "\$0.00",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      DateTime now = DateTime.now();
                      DateTime startOfYear = DateTime(now.year);

                      return TransactionsPage(
                        startingDateRange: DateTimeRange(
                          start: startOfYear,
                          end: now,
                        ),
                      );
                    }),
                  );
                },
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
  final Function? onPressed;

  const OverviewCard(
      {super.key, required this.title, required this.content, this.onPressed});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    Widget cardContent = Padding(
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
    );

    if (onPressed != null) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        color: theme.colorScheme.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed as void Function()?,
          child: cardContent,
        ),
      );
    } else {
      return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          color: theme.colorScheme.primaryContainer,
          child: cardContent);
    }
  }
}
