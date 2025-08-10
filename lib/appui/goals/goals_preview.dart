import 'package:budget/appui/components/status.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/services/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/appui/goals/view_goal.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:provider/provider.dart';

class GoalPreviewButton extends StatelessWidget {
  final GoalWithAmount goalPair;

  const GoalPreviewButton({super.key, required this.goalPair});

  double get achievedAmount => goalPair.netAmount;
  double get goalCost => goalPair.goal.cost;
  String get title => goalPair.goal.name;

  @override
  Widget build(BuildContext context) {
    final formattedAmount = formatAmount(achievedAmount);
    final formattedGoalCost = formatAmount(goalCost);

    final percentage = goalPair.calculatePercentage();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GoalViewer(initialGoalPair: goalPair),
            ),
          ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (percentage < 1) return;

                final manager = DeletionManager(context);

                manager.stageObjectsForArchival<Goal>([goalPair.goal.id]);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (percentage >= 1)
                    Icon(
                      size: 28,
                      Symbols.check,
                      color: Theme.of(context).colorScheme.primary,
                      weight: 900,
                    ),
                  CircularProgressIndicator(
                    value: percentage,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.onSecondaryContainer.withAlpha(68),
                    strokeCap: StrokeCap.round,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    overflow: TextOverflow.ellipsis,
                    title,
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    '\$$formattedAmount of \$$formattedGoalCost',
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer.withAlpha(150),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(2.0),
              child: Icon(
                size: 32,
                Icons.keyboard_arrow_right,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoalPreviewCard extends StatefulWidget {
  const GoalPreviewCard({super.key});

  @override
  State<GoalPreviewCard> createState() => _GoalPreviewCardState();
}

class _GoalPreviewCardState extends State<GoalPreviewCard> {
  bool hasGoals = true;

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Your goals',
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            StreamBuilder<List<GoalWithAmount>>(
              stream: db.goalDao.watchGoals(
                goalFilters: [ArchivedFilter(false)],
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  AppLogger().logger.e(snapshot.error.toString());
                  return SizedBox(
                    height: 100,
                    child: ErrorInset('Error loading goals'),
                  );
                }

                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                } else if (snapshot.hasData && snapshot.data!.isEmpty) {
                  hasGoals = false;
                  return SizedBox(height: 100, child: ErrorInset('No goals'));
                }

                hasGoals = true;

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder:
                        (context, index) =>
                            GoalPreviewButton(goalPair: snapshot.data![index]),
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
