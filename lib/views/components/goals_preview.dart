import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GoalPreviewButton extends StatelessWidget {
  final String title;
  final double amount;
  final double maxAmount;

  const GoalPreviewButton({
    super.key,
    required this.title,
    required this.amount,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAmount = formatAmount(amount);
    final formattedMaxAmount = formatAmount(maxAmount);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CircularProgressIndicator(
              value: amount / maxAmount,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSecondaryContainer.withAlpha(68),
              strokeCap: StrokeCap.round,
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
                    "\$$formattedAmount of \$$formattedMaxAmount",
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
    final goalDao = context.read<GoalDao>();

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
                hasGoals ? "Your goals" : "No goals",
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: StreamBuilder(
                stream: goalDao.watchGoals(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  } else if (snapshot.hasData && snapshot.data!.isEmpty) {
                    hasGoals = false;
                    return const SizedBox.shrink();
                  }

                  hasGoals = true;

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder:
                        (context, index) => GoalPreviewButton(
                          title: snapshot.data![index].goal.name,
                          amount: snapshot.data![index].achievedAmount ?? 0,
                          maxAmount: snapshot.data![index].goal.cost,
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
