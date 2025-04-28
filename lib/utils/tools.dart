import 'package:flutter/material.dart';

Color getAdjustedColor(BuildContext context, Color color,
    {double amount = 0.04}) {
  // Courtesy of Gemini 2.5 Pro
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

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

extension RangeModifier on DateTime {
  // Tells us if a date is within a certain DateTimeRange
  bool isInRange(DateTimeRange range) =>
      (isAfter(range.start) || isAtSameMomentAs(range.start)) &&
      (isBefore(range.end) || isAtSameMomentAs(range.end));
}

extension InclusiveModifier on DateTimeRange {
  DateTimeRange makeInclusive() {
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(end.year, end.month, end.day + 1)
          .subtract(const Duration(microseconds: 1)),
    );
  }
}
