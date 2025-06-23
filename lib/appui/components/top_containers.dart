import 'package:budget/appui/categories/view_category.dart';
import 'package:budget/appui/components/status.dart';
import 'package:budget/appui/goals/view_goal.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TopContainers extends StatefulWidget {
  const TopContainers({super.key});

  @override
  State<TopContainers> createState() => _TopContainersState();
}

class _TopContainersState extends State<TopContainers> {
  ContainerType _selectedContainer = ContainerType.category;

  Stream<List<ContainerTile>> _getStream() {
    final db = context.read<AppDatabase>();
    final filters = context.watch<TransactionProvider>().filters;

    // These streams are meant to return ContainerTiles, which have progress
    // bars. The progress bars represent the total amount of money spent
    // regarding the filtered information. The full progress bar represents the
    // total amount of money that has passed through that type of container,
    // while the progress represents how much money has passed through that
    // specific container.

    // TODO: Make this code reusable instead of copy and pasting the same
    // thing to each stream

    return switch (_selectedContainer) {
      ContainerType.category =>
        db.categoryDao.watchCategories(filters: filters).map((e) {
          // Get the containers that have actually had money pass through them
          final categories = e.where((cp) => cp.cumulativeAmount != 0).toList();

          if (categories.isEmpty) return [];

          // Sort these categories from most cash flow to least cash flow
          categories.sort(
            (a, b) => b.cumulativeAmount.compareTo(a.cumulativeAmount),
          );

          // Combine all the categories' amounts to get the total amount
          final totalAmount = categories.fold(
            0.0,
            (amt, pair) => amt + pair.cumulativeAmount,
          );

          return categories
              .map(
                (c) => ContainerTile(
                  title: c.category.name,
                  leadingIcon: Icons.category,
                  progress: c.cumulativeAmount / totalAmount,
                  amount: c.cumulativeAmount,
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoryViewer(categoryPair: c),
                        ),
                      ),
                ),
              )
              .toList();
        }),
      ContainerType.account => db.accountDao
          .watchAccounts(filters: filters)
          .map((e) {
            final accounts = e.where((ap) => ap.cumulativeAmount != 0).toList();

            if (accounts.isEmpty) return [];

            accounts.sort(
              (a, b) => b.cumulativeAmount.compareTo(a.cumulativeAmount),
            );

            final totalAmount = accounts.fold(
              0.0,
              (amt, pair) => amt + pair.cumulativeAmount,
            );

            return accounts
                .map(
                  (a) => ContainerTile(
                    title: a.account.name,
                    leadingIcon: Icons.account_balance,
                    progress: a.cumulativeAmount / totalAmount,
                    amount: a.cumulativeAmount,
                  ),
                )
                .toList();
          }),
      ContainerType.goal => db.goalDao.watchGoals(filters: filters).map((e) {
        final goals = e.where((gp) => gp.cumulativeAmount != 0).toList();

        if (goals.isEmpty) return [];

        goals.sort((a, b) => b.cumulativeAmount.compareTo(a.cumulativeAmount));

        final totalAmount = goals.fold(
          0.0,
          (amt, pair) => amt + pair.cumulativeAmount,
        );

        return goals
            .map(
              (g) => ContainerTile(
                title: g.goal.name,
                leadingIcon: Icons.flag,
                progress: g.cumulativeAmount / totalAmount,
                amount: g.cumulativeAmount,
                onTap:
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GoalViewer(initialGoalPair: g),
                      ),
                    ),
              ),
            )
            .toList();
      }),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                spacing: 12.0,
                children: [
                  Text('Top', style: Theme.of(context).textTheme.headlineSmall),
                  Expanded(
                    child: DropdownMenu(
                      expandedInsets: EdgeInsets.zero,
                      inputDecorationTheme: InputDecorationTheme(
                        contentPadding: EdgeInsets.zero,
                        // border: InputBorder.none,
                      ),
                      initialSelection: ContainerType.category,
                      textStyle: Theme.of(context).textTheme.headlineSmall,
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          label: 'Categories',
                          value: ContainerType.category,
                        ),
                        DropdownMenuEntry(
                          label: 'Accounts',
                          value: ContainerType.account,
                        ),
                        DropdownMenuEntry(
                          label: 'Goals',
                          value: ContainerType.goal,
                        ),
                      ],
                      onSelected: (value) {
                        if (value != null) {
                          setState(() => _selectedContainer = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.0),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 250),
              child: StreamBuilder(
                stream: _getStream(),
                builder: (context, snapshot) {
                  // The snapshot is probably loading or waiting, or there is no data
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: ErrorInset.noData,
                    );
                  }

                  return Material(
                    color: Colors.transparent,
                    child: ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder:
                          (context, index) => Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: snapshot.data![index],
                          ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ContainerTile extends StatelessWidget {
  final IconData leadingIcon;
  final String title;
  final double progress;
  final double amount;
  final void Function()? onTap;

  const ContainerTile({
    super.key,
    required this.leadingIcon,
    required this.title,
    required this.progress,
    required this.amount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      tileColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      leading: Icon(leadingIcon),
      title: Text(title),
      subtitle: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('\$${formatAmount(amount)}'),
          SizedBox(width: 8.0),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }
}
