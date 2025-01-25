import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/layouts/transactions.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/components/cards.dart';

class TransactionsOverview extends StatefulWidget {
  const TransactionsOverview({super.key});

  @override
  State<TransactionsOverview> createState() => _TransactionsOverviewState();
}

class _TransactionsOverviewState extends State<TransactionsOverview> {
  bool showTransactions = true;

  void setTransactions(bool show) {
    setState(() {
      showTransactions = show;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!showTransactions) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
            flex: 8, child: OverviewHeader(changeParentState: setTransactions)),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
          flex: 8, child: OverviewHeader(changeParentState: setTransactions)),
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

class OverviewHeader extends StatefulWidget {
  /* 
  OverviewHeader is a section at the top of the page with a 2x2 grid of 
  cards that hold information about the user's spending. These cards are:
  - Spending Today
  - Spending This Week
  - Spending This Month
  - Spending This Year
  */
  const OverviewHeader({super.key, required this.changeParentState});

  final Function changeParentState;

  @override
  State<OverviewHeader> createState() => _OverviewHeaderState();
}

class _OverviewHeaderState extends State<OverviewHeader> {
  bool isMinimized = true;

  List<AsyncOverviewCard> getAvailableCards(
      TransactionProvider transactionProvider) {
    DateTime now = DateTime.now();

    return [
      AsyncOverviewCard(
        title: "Spent Today",
        amountCalculator: (provider) => provider.getAmountSpent(DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionsPage(
                startingDateRange: DateTimeRange(
                  start: now,
                  end: now,
                ),
                type: TransactionType.expense,
              ),
            ),
          );
        },
      ),
      AsyncOverviewCard(
        title: "Earned Today",
        amountCalculator: (provider) => provider.getAmountEarned(DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionsPage(
                startingDateRange: DateTimeRange(
                  start: now,
                  end: now,
                ),
                type: TransactionType.income,
              ),
            ),
          );
        },
      ),
      AsyncOverviewCard(
        title: "Spent This Month",
        amountCalculator: (provider) => provider.getAmountSpent(
            DateTimeRange(start: DateTime(now.year, now.month), end: now)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) {
              DateTime startOfMonth = DateTime(now.year, now.month);

              return TransactionsPage(
                startingDateRange: DateTimeRange(
                  start: startOfMonth,
                  end: now,
                ),
                type: TransactionType.expense,
              );
            }),
          );
        },
      ),
      AsyncOverviewCard(
        title: "Earned This Month",
        amountCalculator: (provider) => provider.getAmountEarned(
            DateTimeRange(start: DateTime(now.year, now.month), end: now)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) {
              DateTime startOfMonth = DateTime(now.year, now.month);

              return TransactionsPage(
                startingDateRange: DateTimeRange(
                  start: startOfMonth,
                  end: now,
                ),
                type: TransactionType.income,
              );
            }),
          );
        },
      ),
      AsyncOverviewCard(
          title: "Spent This Week",
          amountCalculator: (provider) => provider.getAmountSpent(DateTimeRange(
              start: now.subtract(Duration(days: now.weekday - 1)), end: now)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) {
                // TODO: Setting that changes the start of the week
                DateTime startOfWeek = now.subtract(
                  Duration(days: now.weekday - 1),
                );

                return TransactionsPage(
                  startingDateRange: DateTimeRange(
                    start: startOfWeek,
                    end: now,
                  ),
                  type: TransactionType.expense,
                );
              }),
            );
          }),
      AsyncOverviewCard(
          title: "Earned this week",
          amountCalculator: (provider) => provider.getAmountEarned(
              DateTimeRange(
                  start: now.subtract(Duration(days: now.weekday - 1)),
                  end: now)),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              DateTime startOfWeek = now.subtract(
                Duration(days: now.weekday - 1),
              );

              return TransactionsPage(
                startingDateRange: DateTimeRange(
                  start: startOfWeek,
                  end: now,
                ),
                type: TransactionType.income,
              );
            }));
          }),
      AsyncOverviewCard(
        title: "Spent This Year",
        amountCalculator: (provider) => provider
            .getAmountSpent(DateTimeRange(start: DateTime(now.year), end: now)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) {
              DateTime startOfYear = DateTime(now.year);

              return TransactionsPage(
                startingDateRange: DateTimeRange(
                  start: startOfYear,
                  end: now,
                ),
                type: TransactionType.expense,
              );
            }),
          );
        },
      ),
      AsyncOverviewCard(
        title: "Earned this year",
        amountCalculator: (provider) => provider.getAmountEarned(
            DateTimeRange(start: DateTime(now.year), end: now)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) {
              DateTime startOfYear = DateTime(now.year);

              return TransactionsPage(
                startingDateRange: DateTimeRange(
                  start: startOfYear,
                  end: now,
                ),
                type: TransactionType.income,
              );
            }),
          );
        },
      ),
    ];
  }

  Widget getMinimized(TransactionProvider transactionProvider) {
    List<AsyncOverviewCard> availableCards =
        getAvailableCards(transactionProvider).sublist(0, 4);
    return Column(children: [
      Expanded(
        child: Row(
          children: [
            Expanded(child: availableCards[0]),
            Expanded(child: availableCards[1]),
          ],
        ),
      ),
      Expanded(
        child: Row(
          children: [
            Expanded(child: availableCards[2]),
            Expanded(child: availableCards[3]),
          ],
        ),
      )
    ]);
  }

  Widget getMaximized(TransactionProvider transactionProvider) {
    List<AsyncOverviewCard> availableCards =
        getAvailableCards(transactionProvider);

    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: availableCards,
    );
  }

  @override
  Widget build(BuildContext context) {
    // When making this stateful, make sure the numbers update when the user
    // adds a new transaction. Also make sure the numbers do not overflow,
    // possibly replace some if they get too big (eg. $1000.00 > $1.0k)
    return Consumer<TransactionProvider>(
      builder: (context, transactionProvider, child) {
        Widget child = getMinimized(transactionProvider);

        if (!isMinimized) {
          child = getMaximized(transactionProvider);
        }

        return GestureDetector(
          onPanUpdate: (details) {
            if (details.delta.dy + 5 < 0) {
              isMinimized = true;
            } else if (details.delta.dy - 5 > 0) {
              isMinimized = false;
            }
          },
          onPanEnd: (details) => {
            setState(() {
              isMinimized = isMinimized;
              widget.changeParentState(isMinimized);
            })
          },
          child: Card(child: child),
        );
      },
    );
  }
}
