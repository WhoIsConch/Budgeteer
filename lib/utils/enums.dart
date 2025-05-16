import 'package:budget/utils/tools.dart';
import 'package:flutter/material.dart';

enum ObjectManageMode { add, edit } // Normal enum

// Enums with values, in case I need to store them in a database
enum TransactionType {
  expense(0),
  income(1);

  const TransactionType(this.value);
  final int value;

  factory TransactionType.fromValue(int value) =>
      values.firstWhere((e) => e.value == value);
}

enum AggregationLevel { daily, weekly, monthly, yearly }

enum RelativeDateRange {
  today('Today'),
  yesterday('Yesterday'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  thisYear('This Year');

  const RelativeDateRange(this.name);
  final String name;

  DateTimeRange getRange({DateTime? fromDate, bool fullRange = false}) {
    DateTime now = fromDate ?? DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final range = switch (this) {
      // From the beginning of the day to right now
      // (or the end of the day)
      RelativeDateRange.today => DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day),
      ),
      // Same thing as above, but for yesterday
      RelativeDateRange.yesterday => DateTimeRange(
        start: DateTime(now.year, now.month, now.day - 1),
        end: DateTime(now.year, now.month, now.day - 1),
      ),
      // From the beginning of the week to right now
      // (or the end of the week)
      RelativeDateRange.thisWeek =>
        fullRange
            ? DateTimeRange(
              start: startOfWeek,
              end: startOfWeek.add(
                const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
              ),
            )
            : DateTimeRange(start: startOfWeek, end: now),
      // From the beginning of the month to right now
      // (or the end of the month)
      RelativeDateRange.thisMonth =>
        fullRange
            ? DateTimeRange(
              start: DateTime(now.year, now.month),
              end: DateTime(now.year, now.month + 1),
            )
            : DateTimeRange(start: DateTime(now.year, now.month), end: now),
      // From the beginning of this year to right now
      // (or the end of the year)
      RelativeDateRange.thisYear =>
        fullRange
            ? DateTimeRange(
              start: DateTime(now.year),
              end: DateTime(now.year + 1),
            )
            : DateTimeRange(start: DateTime(now.year), end: now),
    };

    return range.makeInclusive();
  }
}

enum CategoryResetIncrement {
  daily(1, 'Day'),
  weekly(2, 'Week'),
  // biweekly(3), // This is not currently usable
  monthly(4, 'Month'),
  yearly(5, 'Year'),
  never(0, 'Never Reset');

  const CategoryResetIncrement(this.value, this.text);
  final num value;
  final String text;

  factory CategoryResetIncrement.fromValue(int value) {
    return values.firstWhere((e) => e.value == value);
  }

  String capitalizedName() {
    if (value == 0) return 'Forever';

    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  RelativeDateRange? get relativeDateRange => switch (value) {
    1 => RelativeDateRange.today,
    2 => RelativeDateRange.thisWeek,
    4 => RelativeDateRange.thisMonth,
    5 => RelativeDateRange.thisYear,
    _ => null,
  };
}

enum PageType {
  home(0),
  transactions(1);

  const PageType(this.value);
  final int value;
}
