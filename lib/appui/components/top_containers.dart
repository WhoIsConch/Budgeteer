import 'package:budget/appui/categories/view_category.dart';
import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/appui/components/status.dart';
import 'package:budget/appui/goals/view_goal.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
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

    return switch (_selectedContainer) {
      ContainerType.category => db.categoryDao
          .watchCategories(filters: filters, net: false)
          .map((e) {
            final categories = e.where((cp) => cp.amount != 0).toList();

            if (categories.isEmpty) return [];

            categories.sort((a, b) => b.amount.compareTo(a.amount));

            final maxAmount = categories[0].amount;

            return categories
                .map(
                  (c) => ContainerTile(
                    title: c.category.name,
                    leadingIcon: Icons.category,
                    progress: c.amount / maxAmount,
                    amount: c.amount,
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
          .watchAccounts(filters: filters, net: false)
          .map((e) {
            final accounts = e.where((ap) => ap.total != 0).toList();

            if (accounts.isEmpty) return [];

            accounts.sort((a, b) => b.total.compareTo(a.total));
            final maxTotal = accounts[0].total;

            return accounts
                .map(
                  (a) => ContainerTile(
                    title: a.account.name,
                    leadingIcon: Icons.account_balance,
                    progress: a.total / maxTotal,
                    amount: a.total,
                  ),
                )
                .toList();
          }),
      ContainerType.goal => db.goalDao
          .watchGoals(filters: filters, net: false)
          .map((e) {
            final goals = e.where((gp) => gp.achievedAmount != 0).toList();

            if (goals.isEmpty) return [];

            goals.sort((a, b) => b.achievedAmount.compareTo(a.achievedAmount));
            final maxAmount = goals[0].achievedAmount;

            return goals
                .map(
                  (g) => ContainerTile(
                    title: g.goal.name,
                    leadingIcon: Icons.flag,
                    progress: g.achievedAmount / maxAmount,
                    amount: g.achievedAmount,
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
            StreamBuilder(
              stream: _getStream(),
              builder: (context, snapshot) {
                // The snapshot is probably loading or waiting
                if (!snapshot.hasData) {
                  return ErrorInset.noData;
                }

                // The snapshot finished, but the list is empty
                if (snapshot.data!.isEmpty) return ErrorInset.noData;

                return ListView.builder(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: snapshot.data!.length,
                  itemBuilder:
                      (context, index) => Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: snapshot.data![index],
                      ),
                );
              },
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
