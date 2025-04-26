import 'package:budget/models/filters.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/views/components/accounts_carousel.dart';
import 'package:budget/views/components/goals_preview.dart';
import 'package:budget/views/panels/manage_transaction.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TransactionDao dao;

  Future<double> getTotal() async {
    final spent = await dao.getTotalAmount(type: TransactionType.expense);
    final earned = await dao.getTotalAmount(type: TransactionType.income);

    return earned - spent;
  }

  @override
  Widget build(BuildContext context) {
    dao = context.watch<TransactionDao>();

    return Scaffold(
      body: SingleChildScrollView(
        // The main content
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WelcomeHeader(),
          FutureBuilder(
            future: getTotal(),
            initialData: 0.0,
            builder: (context, snapshot) {
              bool isNegative = snapshot.data as double < 0;
              String formattedAmount =
                  formatAmount((snapshot.data as double).abs(), exact: true);

              return AccountsCarousel(items: [
                CarouselCardPair(
                  "Total balance",
                  "${isNegative ? '-' : ''}\$$formattedAmount",
                  isNegative: true,
                ),
                CarouselCardPair("Checking", "\$4,182.33"),
                CarouselCardPair("Cash", "\$130.50"),
              ]);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                Text("Recent activity",
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurface)),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.arrow_forward),
                  onPressed: () {},
                )
              ],
            ),
          ),
          TransactionPreviewer(),
          SizedBox(height: 8),
          GoalPreviewCard(),
        ]),
      ),
    );
  }
}

class TransactionPreviewer extends StatelessWidget {
  const TransactionPreviewer({super.key});

  @override
  Widget build(BuildContext context) {
    final TransactionDao dao = context.watch<TransactionDao>();

    return SizedBox(
      height: 160,
      child: StreamBuilder(
          stream: dao.watchTransactionsPage(filters: [
            TransactionFilter(DateTimeRange(
                start: DateTime.now().subtract(Duration(days: 7)),
                end: DateTime.now()))
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            return ListView.builder(
              shrinkWrap: true,
              scrollDirection: Axis.horizontal,
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) =>
                  TransactionPreviewCard(transaction: snapshot.data![index]),
            );
          }),
    );
  }
}

class TransactionPreviewCard extends StatelessWidget {
  final Transaction transaction;

  const TransactionPreviewCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(12), // To match the card's radius
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ManageTransactionDialog(
                  mode: ObjectManageMode.edit, transaction: transaction)));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Expense",
                    style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiaryContainer)),
                Text("\$${formatAmount(transaction.amount)}",
                    style: theme.textTheme.headlineLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiaryContainer)),
                Text(transaction.title,
                    style: theme.textTheme.titleMedium!.copyWith(
                        color: theme.colorScheme.onTertiaryContainer)),
                Text(DateFormat('M/d/yy').format(transaction.date),
                    style: theme.textTheme.bodyLarge!.copyWith(
                        color: theme.colorScheme.onTertiaryContainer
                            .withAlpha(150)))
              ]),
        ),
      ),
    );
  }
}

class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("Welcome, Noah",
            softWrap: true,
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(color: Theme.of(context).colorScheme.onSurface)),
        IconButton(
          icon: Icon(Icons.person),
          onPressed: () {},
        )
      ]),
    );
  }
}
