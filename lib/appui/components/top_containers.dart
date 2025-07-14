import 'package:budget/appui/categories/view_category.dart';
import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/appui/components/status.dart';
import 'package:budget/appui/goals/view_goal.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TopContainers extends StatefulWidget {
  const TopContainers({super.key});

  @override
  State<TopContainers> createState() => _TopContainersState();
}

class _TopContainersState extends State<TopContainers> {
  SecondaryObjectType _selectedContainer = SecondaryObjectType.category;

  Stream<List<ContainerTile>> _getStream() {
    final db = context.read<AppDatabase>();
    final filters = context.watch<TransactionProvider>().filters;

    // These streams are meant to return ContainerTiles, which have progress
    // bars. The progress bars represent the total amount of money spent
    // regarding the filtered information. The full progress bar represents the
    // total amount of money that has passed through that type of container,
    // while the progress represents how much money has passed through that
    // specific container.

    final stream = db.getObjectStream(
      filters: filters,
      objectType: _selectedContainer,
    );

    return stream.map((e) {
      // Weed out any objects that don't have any data
      final objs = e.where((obj) => obj.cumulativeAmount != 0).toList();

      if (objs.isEmpty) return [];

      // Sort in descending order
      objs.sort((a, b) => b.cumulativeAmount.compareTo(a.cumulativeAmount));

      final totalAmount = objs.fold(
        0.0,
        (amt, pair) => amt + pair.cumulativeAmount,
      );

      return objs
          .map(
            (o) => ContainerTile(
              title: o.object.name,
              leadingIcon: _selectedContainer.icon,
              progress: o.cumulativeAmount / totalAmount,
              amount: o.cumulativeAmount,
              onTap: switch (_selectedContainer) {
                SecondaryObjectType.category =>
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => CategoryViewer(
                            categoryPair: o as CategoryWithAmount,
                          ),
                    ),
                  ),
                SecondaryObjectType.account => null,
                SecondaryObjectType.goal =>
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              GoalViewer(initialGoalPair: o as GoalWithAmount),
                    ),
                  ),
              },
            ),
          )
          .toList();
    });
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
                      initialSelection: SecondaryObjectType.category,
                      textStyle: Theme.of(context).textTheme.headlineSmall,
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          label: 'Categories',
                          value: SecondaryObjectType.category,
                        ),
                        DropdownMenuEntry(
                          label: 'Accounts',
                          value: SecondaryObjectType.account,
                        ),
                        DropdownMenuEntry(
                          label: 'Goals',
                          value: SecondaryObjectType.goal,
                        ),
                      ],
                      onSelected: (value) {
                        if (value != null) {
                          setState(() => _selectedContainer = value);
                        }
                      },
                    ),
                  ),
                  IconButtonWithTooltip(
                    tooltipText:
                        'Applies your filters from the above pie chart',
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.0),
            StreamBuilder(
              stream: _getStream(),
              builder: (context, snapshot) {
                // The snapshot is probably loading or waiting, or there is no data
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SizedBox(
                    height: 150,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: ErrorInset.noData,
                    ),
                  );
                }

                // Wrap with a Material widget to make the tiles clip
                // correctly. Without it, they don't clip outside of the
                // ListView's bounds and render underneath other widgets in
                // the Column
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 250),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListView.builder(
                      itemCount: snapshot.data!.length,
                      shrinkWrap: true,
                      itemBuilder:
                          (context, index) => Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: snapshot.data![index],
                          ),
                    ),
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
          Text('\$${formatAmount(amount, truncateIfWhole: false)}'),
          Spacer(),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
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
