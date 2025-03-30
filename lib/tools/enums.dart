import 'package:flutter/material.dart';

enum ObjectManageMode { add, edit } // Normal enum

enum AmountFilterType { greaterThan, lessThan, exactly }

// Enums with values, in case I need to store them in a database
enum TransactionType {
  expense(0),
  income(1);

  const TransactionType(this.value);
  final int value;
}

enum RelativeTimeRange {
  today("Today"),
  yesterday("Yesterday"),
  thisWeek("This Week"),
  thisMonth("This Month"),
  thisYear("This Year");

  const RelativeTimeRange(this.name);
  final String name;

  DateTimeRange getRange() {
    DateTime now = DateTime.now();

    return switch (this) {
      RelativeTimeRange.today =>
        DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now),
      RelativeTimeRange.yesterday => DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 1),
          end: DateTime(now.year, now.month, now.day)),
      RelativeTimeRange.thisWeek => DateTimeRange(
          start: DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1)),
          end: now),
      RelativeTimeRange.thisMonth =>
        DateTimeRange(start: DateTime(now.year, now.month), end: now),
      RelativeTimeRange.thisYear =>
        DateTimeRange(start: DateTime(now.year), end: now),
    };
  }
}

enum CategoryResetIncrement {
  daily(1),
  weekly(2),
  biweekly(3),
  monthly(4),
  yearly(5),
  never(0);

  const CategoryResetIncrement(this.value);
  final num value;

  factory CategoryResetIncrement.fromValue(int value) {
    return values.firstWhere((e) => e.value == value);
  }

  String getText() => switch (value) {
        1 => "Day",
        2 => "Week",
        3 => "Two Weeks",
        4 => "Month",
        5 => "Year",
        0 => "Never Reset",
        _ => "Error"
      };
}

enum PageType {
  home(0),
  transactions(1);

  const PageType(this.value);
  final int value;
}

// Not by definition an enum but it works nonetheless
class AmountFilter {
  final AmountFilterType? type;
  final double? value;

  AmountFilter({this.type, this.value});

  bool isPopulated() {
    return type != null && value != null;
  }
}

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
