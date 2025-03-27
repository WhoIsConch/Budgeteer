import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/layouts/transactions.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/components/cards.dart';

class CardConfig {
  final String title;
  final TransactionType type;
  final DateTimeRange Function() dateRange;

  CardConfig({
    required this.title,
    required this.type,
    required this.dateRange,
  });
}

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
  final List<String> _previousContents = List.filled(8, '\$0.00');

  void _updatePreviousContent(int index, String newContent) {
    _previousContents[index] = newContent;
  }

  List<CardConfig> get cardConfigs {
    DateTime now = DateTime.now();

    return [
      CardConfig(
          title: "Spent Today",
          type: TransactionType.expense,
          dateRange: () => DateTimeRange(
              start: DateTime(now.year, now.month, now.day), end: now)),
      CardConfig(
          title: "Earned Today",
          type: TransactionType.income,
          dateRange: () => DateTimeRange(
              start: DateTime(now.year, now.month, now.day), end: now)),
      CardConfig(
        title: "Spent This Month",
        type: TransactionType.expense,
        dateRange: () =>
            DateTimeRange(start: DateTime(now.year, now.month), end: now),
      ),
      CardConfig(
          title: "Earned This Month",
          type: TransactionType.income,
          dateRange: () =>
              DateTimeRange(start: DateTime(now.year, now.month), end: now)),
      CardConfig(
          title: 'Spent This Week',
          type: TransactionType.expense,
          dateRange: () => DateTimeRange(
              start: now.subtract(Duration(days: now.weekday - 1)), end: now)),
      CardConfig(
          title: 'Earned This Week',
          type: TransactionType.income,
          dateRange: () => DateTimeRange(
              start: now.subtract(Duration(days: now.weekday - 1)), end: now)),
      CardConfig(
          title: "Spent This Year",
          type: TransactionType.expense,
          dateRange: () => DateTimeRange(start: DateTime(now.year), end: now)),
      CardConfig(
          title: "Earned This Year",
          type: TransactionType.income,
          dateRange: () => DateTimeRange(start: DateTime(now.year), end: now))
    ];
  }

  List<Widget> getAvailableCards(TransactionProvider transactionProvider) {
    return List.generate(cardConfigs.length, (index) {
      final config = cardConfigs[index];

      return Padding(
        padding: const EdgeInsets.all(4.0),
        child: AsyncOverviewCard(
          title: config.title,
          previousContent: _previousContents[index],
          amountCalculator: (provider) => config.type == TransactionType.expense
              ? provider.getAmountSpent(config.dateRange())
              : provider.getAmountEarned(config.dateRange()),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => TransactionsPage(
                          startingDateRange: config.dateRange(),
                          startingTransactionType: config.type,
                        )));
          },
          onContentUpdated: (newContent) =>
              _updatePreviousContent(index, newContent),
        ),
      );
    });
  }

  Widget getMinimized(TransactionProvider transactionProvider) {
    List<Widget> availableCards =
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
    List<Widget> availableCards = getAvailableCards(transactionProvider);

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
