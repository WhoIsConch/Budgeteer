import 'package:flutter/material.dart';

class GoalPreviewButton extends StatelessWidget {
  final String title;
  final int amount;
  final int maxAmount;

  const GoalPreviewButton(
      {super.key,
      required this.title,
      required this.amount,
      required this.maxAmount});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
          CircularProgressIndicator(
            value: amount / maxAmount,
            backgroundColor: Theme.of(context)
                .colorScheme
                .onSecondaryContainer
                .withAlpha(68),
            strokeCap: StrokeCap.round,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    overflow: TextOverflow.ellipsis,
                    title,
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer)),
                Text("\$$amount of \$$maxAmount",
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withAlpha(150)))
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: Icon(
                size: 32,
                Icons.keyboard_arrow_right,
                color: Theme.of(context).colorScheme.outline),
          )
        ]),
      ),
    );
  }
}

class GoalPreviewCard extends StatelessWidget {
  const GoalPreviewCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text("Your goals",
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer)),
              ),
              GoalPreviewButton(
                title: "A Puppy",
                amount: 120,
                maxAmount: 200,
              ),
              GoalPreviewButton(
                  title: "Baseball Tickets", amount: 200, maxAmount: 450),
              GoalPreviewButton(
                  title: "Spongebob Toybobson", amount: 13, maxAmount: 15),
            ],
          ),
        ));
  }
}
