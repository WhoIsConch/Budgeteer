import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/appui/accounts/accounts_carousel.dart';
import 'package:budget/appui/goals/goals_preview.dart';
import 'package:budget/utils/ui.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/appui/transactions/view_transaction.dart';
import 'package:budget/appui/pages/transaction_search.dart';
import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late AppDatabase db;

  @override
  Widget build(BuildContext context) {
    db = context.watch<AppDatabase>();

    return Scaffold(
      body: SingleChildScrollView(
        clipBehavior: Clip.none,
        // The main content
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WelcomeHeader(),
            AccountsCarousel(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
              child: Row(
                children: [
                  Text(
                    'Recent activity',
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TransactionSearch(),
                          ),
                        ),
                    child: Row(
                      children: [
                        Text(
                          'View all',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(200),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(200),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const TransactionPreviewer(),
            const SizedBox(height: 8),
            const GoalPreviewCard(),
          ],
        ),
      ),
    );
  }
}

class TransactionPreviewer extends StatelessWidget {
  const TransactionPreviewer({super.key});

  @override
  Widget build(BuildContext context) {
    final AppDatabase db = context.watch<AppDatabase>();

    return StreamBuilder<List<Transaction>>(
      stream: db.transactionDao.watchTransactionsPage(
        limit: 10,
        filters: [
          TransactionFilter<DateTimeRange>(
            DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ).makeInclusive(),
          ),
        ],
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
        } else {
          if (snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No recent transactions',
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
              ),
            );
          }
        }

        return SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: snapshot.data!.length,
            clipBehavior: Clip.none,
            itemBuilder:
                (context, index) =>
                    TransactionPreviewCard(transaction: snapshot.data![index]),
          ),
        );
      },
    );
  }
}

class TransactionPreviewCard extends StatelessWidget {
  final Transaction transaction;

  const TransactionPreviewCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    Color? reactiveTextColor;
    Color defaultTextColor = Theme.of(context).colorScheme.onSurface;
    Color backgroundColor = Theme.of(
      context,
    ).colorScheme.onSurface.withAlpha(150);

    if (transaction.type == TransactionType.income) {
      reactiveTextColor = Colors.green.harmonizeWith(
        Theme.of(context).colorScheme.surface,
      );
    }

    bool isExpense = reactiveTextColor == null;

    return SizedBox(
      width: 135,
      height: 200,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(12), // To match the card's radius
          onTap: () async {
            final db = context.read<AppDatabase>();
            final hydrated = await db.transactionDao.hydrateTransaction(
              transaction,
            );

            if (!context.mounted) return;

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ViewTransaction(transactionData: hydrated),
              ),
            );
          },
          onLongPress: () => showOptionsDialog(context, transaction),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              spacing: 4.0,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TODO : Category Icons
                Icon(
                  isExpense ? Icons.remove_circle : Icons.add_circle,
                  color: reactiveTextColor ?? backgroundColor,
                  size: 32,
                ),
                SizedBox(
                  height: 36,
                  child: AutoSizeText(
                    "${isExpense ? '-' : '+'}\$${formatAmount(transaction.amount, round: transaction.amount >= 1000)}",
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      color: reactiveTextColor ?? defaultTextColor,
                    ),
                    maxLines: 1,
                  ),
                ),
                Text(
                  transaction.title,
                  style: TextStyle(color: defaultTextColor, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const Spacer(),
                Text(
                  DateFormat(
                    DateFormat.ABBR_MONTH_DAY,
                  ).format(transaction.date),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium!.copyWith(color: backgroundColor),
                ),
              ],
            ),
          ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Welcome, Noah',
            softWrap: true,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(icon: const Icon(Icons.person), onPressed: () {}),
        ],
      ),
    );
  }
}
