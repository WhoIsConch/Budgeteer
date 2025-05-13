import 'package:auto_size_text/auto_size_text.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

Color getAdjustedColor(BuildContext context, Color color,
    {double amount = 0.04}) {
  final Brightness brightness = Theme.of(context).brightness;

  // Convert the surface color to HSL
  final HSLColor hslSurfaceColor = HSLColor.fromColor(color);

  // Determine the adjustment direction based on brightness
  final double adjustment = (brightness == Brightness.dark) ? amount : -amount;

  // Calculate the new lightness, clamping it between 0.0 and 1.0
  // clamp() ensures the value stays within the valid range for lightness
  final double newLightness =
      (hslSurfaceColor.lightness + adjustment).clamp(0.0, 1.0);

  // Create the new HSL color with the adjusted lightness
  final HSLColor adjustedHslColor = hslSurfaceColor.withLightness(newLightness);

  // Convert back to a standard Color object
  return adjustedHslColor.toColor();
}

class TransactionCard extends StatelessWidget {
  const TransactionCard({super.key});

  Color greenColor(BuildContext context) =>
      Colors.green.harmonizeWith(Theme.of(context).colorScheme.surface);

  Widget getCard(BuildContext context) => SizedBox(
        width: 125,
        height: 200,
        child: Card(
            margin: EdgeInsets.zero,
            color: getAdjustedColor(
                context, Theme.of(context).colorScheme.surface),
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  spacing: 4.0,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shopping_bag,
                        color: greenColor(context), size: 32),
                    SizedBox(
                        height: 36,
                        child: AutoSizeText("+\$8.00",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall!
                                .copyWith(color: greenColor(context)),
                            maxLines: 1)),
                    Text("Hello",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2),
                    const Spacer(),
                    Text("Apr 28",
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withAlpha(200)))
                  ],
                ))),
      );

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(children: [
                  Text("Recent activity",
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium!
                          .copyWith(
                              color: Theme.of(context).colorScheme.onSurface)),
                  const Spacer(),
                  Text("View all",
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(200))),
                  Icon(Icons.chevron_right,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(200)),
                ]),
              ),
              SingleChildScrollView(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8.0,
                  children: [
                    getCard(context),
                    getCard(context),
                    getCard(context),
                    getCard(context)
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
