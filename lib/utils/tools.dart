import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String asString() {
    DateFormat formatter = DateFormat(DateFormat.ABBR_MONTH_DAY);

    return "${formatter.format(start)}–${formatter.format(end)}";
  }
}

// Courtesy of Gemini
double calculateNiceInterval(
  double minY,
  double maxY,
  int desiredIntervals,
) {
  // --- Input Validation ---
  if (desiredIntervals <= 0) {
    desiredIntervals = 1; // Prevent division by zero or nonsensical results
  }
  if (maxY < minY) {
    // Swap if min/max are reversed
    final temp = maxY;
    maxY = minY;
    minY = temp;
  }
  if (maxY == minY) {
    // Handle zero range - return a sensible default or based on the value
    return maxY != 0 ? (maxY / desiredIntervals).abs() : 1.0;
  }

  final double range = maxY - minY;

  // --- Calculate Raw Interval ---
  // This is the interval if we didn't care about "niceness"
  final double rawInterval = range / desiredIntervals;

  // --- Calculate Magnitude ---
  // Find the exponent of the nearest power of 10 below the raw interval
  // Example: rawInterval = 17500 -> exponent = 4 (10^4 = 10000)
  // Example: rawInterval = 18.75 -> exponent = 1 (10^1 = 10)
  // Example: rawInterval = 0.15 -> exponent = -1 (10^-1 = 0.1)
  final double exponent = (log(rawInterval) / ln10).floor().toDouble();
  final double magnitude = pow(10, exponent).toDouble();

  // --- Normalize the Step ---
  // Get a value usually between 1 and 10 by dividing by the magnitude
  // Example: 17500 / 10000 = 1.75
  // Example: 18.75 / 10 = 1.875
  // Example: 0.15 / 0.1 = 1.5
  final double normalizedStep = rawInterval / magnitude;

  // --- Choose Nice Normalized Step ---
  // Pick the smallest "nice" number (1, 2, 5, 10) >= normalized step
  double niceNormalizedStep;
  if (normalizedStep <= 1.0) {
    niceNormalizedStep = 1.0;
  } else if (normalizedStep <= 2.0) {
    niceNormalizedStep = 2.0;
  } else if (normalizedStep <= 5.0) {
    niceNormalizedStep = 5.0;
  } else {
    niceNormalizedStep = 10.0;
  }

  // --- Calculate Final Nice Interval ---
  // Multiply the nice normalized step by the magnitude
  // Example: 2.0 * 10000 = 20000
  // Example: 2.0 * 10 = 20
  // Example: 2.0 * 0.1 = 0.2
  final double niceInterval = niceNormalizedStep * magnitude;

  return niceInterval;
}

/// Optional Helper: Adjusts maxY to be the next multiple of the nice interval.
/// This makes the top axis label align nicely with a grid line.
double adjustMaxYToNiceInterval(double maxY, double niceInterval) {
  if (niceInterval <= 0) return maxY; // Avoid division by zero
  // Use a small epsilon to handle floating point precision issues near multiples
  const double epsilon = 1e-9;
  return ((maxY + epsilon) / niceInterval).ceil() * niceInterval;
}
