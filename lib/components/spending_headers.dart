import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/panels/spending.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/components/cards.dart';

class CardConfig {
  final String title;
  final TransactionType type;
  final DateTimeRange dateRange;

  CardConfig({
    required this.title,
    required this.type,
    required this.dateRange,
  });
}

class SpendingOverview extends StatefulWidget {
  const SpendingOverview({super.key});

  @override
  State<SpendingOverview> createState() => _SpendingOverviewState();
}

class _SpendingOverviewState extends State<SpendingOverview> {
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
            flex: 8, child: SpendingHeader(changeParentState: setTransactions)),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
          flex: 8, child: SpendingHeader(changeParentState: setTransactions)),
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
                        builder: (context) => const SpendingPage(),
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

class SpendingHeader extends StatefulWidget {
  /* 
  OverviewHeader is a section at the top of the page with a 2x2 grid of 
  cards that hold information about the user's spending. These cards are:
  - Spending Today
  - Spending This Week
  - Spending This Month
  - Spending This Year
  */
  const SpendingHeader({super.key, required this.changeParentState});

  final Function changeParentState;

  @override
  State<SpendingHeader> createState() => _SpendingHeaderState();
}

class _SpendingHeaderState extends State<SpendingHeader> {
  bool isMinimized = true;
  final List<String> _previousContents = List.filled(8, '\$0.00');

  void _updatePreviousContent(int index, String newContent) {
    _previousContents[index] = newContent;
  }

  List<CardConfig> get cardConfigs {
    return [
      CardConfig(
          title: "Spent Today",
          type: TransactionType.expense,
          dateRange: RelativeDateRange.today.getRange()),
      CardConfig(
          title: "Earned Today",
          type: TransactionType.income,
          dateRange: RelativeDateRange.today.getRange()),
      CardConfig(
        title: "Spent This Month",
        type: TransactionType.expense,
        dateRange: RelativeDateRange.thisMonth.getRange(),
      ),
      CardConfig(
          title: "Earned This Month",
          type: TransactionType.income,
          dateRange: RelativeDateRange.thisMonth.getRange()),
      CardConfig(
          title: 'Spent This Week',
          type: TransactionType.expense,
          dateRange: RelativeDateRange.thisWeek.getRange()),
      CardConfig(
          title: 'Earned This Week',
          type: TransactionType.income,
          dateRange: RelativeDateRange.thisWeek.getRange()),
      CardConfig(
          title: "Spent This Year",
          type: TransactionType.expense,
          dateRange: RelativeDateRange.thisYear.getRange()),
      CardConfig(
          title: "Earned This Year",
          type: TransactionType.income,
          dateRange: RelativeDateRange.thisYear.getRange())
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
              ? provider.getAmountSpent(config.dateRange)
              : provider.getAmountEarned(config.dateRange),
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SpendingPage(
                          startingDateRange: config.dateRange,
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
          child: Card(
            child: child,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        );
      },
    );
  }
}
