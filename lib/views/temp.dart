import 'package:auto_size_text/auto_size_text.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

class TransactionCard extends StatelessWidget {
  const TransactionCard ({super.key});

  Color greenColor(BuildContext context) => Colors.green.harmonizeWith(Theme.of(context).colorScheme.surface);

  Widget getCard(BuildContext context) => SizedBox(
    width: 125,
    height: 200,
    child: Card(
            color: Theme.of(context).colorScheme.surface.withAlpha(150),
            child: Padding(padding: EdgeInsets.all(16.0), child: Column(
              spacing: 4.0,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Icon(Icons.shopping_bag, color: greenColor(context), size: 32), 
              SizedBox(
                height: 36,
                child: AutoSizeText("+\$8.00", style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: greenColor(context)), maxLines: 1)
                ), 
              Text("Hello", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18), overflow: TextOverflow.ellipsis, maxLines: 2), 
              Spacer(),
              Text("Apr 28", style: Theme.of(context).textTheme.titleSmall!.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(200)))
              ],))
          ),
  );

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
      color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                  Text("Recent activity", style: Theme.of(context).textTheme.headlineMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface)), 
                  Spacer(), 
                  Text("View all", style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: Theme.of(context).colorScheme.onSurface.withAlpha(200))),
                  Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withAlpha(200)),
                  ]),
              ),
              SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                      children: [getCard(context), getCard(context), getCard(context), getCard(context)],),
            ),]
          ),
        ),
      ),
    );
  }
}