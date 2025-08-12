import 'dart:math';

import 'package:budget/services/app_database.dart';
import 'package:budget/models/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final formatter = DateFormat('yyyy-MM-dd');

int genColor() =>
    Color((Random().nextDouble() * 0xFFFFFF).toInt()).withAlpha(255).toARGB32();

/// Represents a container object and the expenses and income associated with
/// it.
abstract class ContainerWithAmount<T extends SecondaryObject> {
  /// The object in question. Could be a Category, Account, or Goal
  T get object;
  String get objectId;

  /// The amount of money that has been deposited into this object as
  /// an expense
  double expenses;

  /// The amount of money that has been deposited into this object as
  /// an income
  double income;

  double get netAmount => income - expenses;
  double get cumulativeAmount => income + expenses;

  ContainerWithAmount({required this.income, required this.expenses});

  @override
  int get hashCode => object.hashCode ^ expenses.hashCode ^ income.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContainerWithAmount &&
          runtimeType == other.runtimeType &&
          object == other.object &&
          expenses == other.expenses &&
          income == other.income;
}

class GoalWithAmount extends ContainerWithAmount {
  final Goal goal;

  @override
  Goal get object => goal;

  @override
  String get objectId => goal.id;

  GoalWithAmount({
    required this.goal,
    required super.expenses,
    required super.income,
  });

  double calculatePercentage() {
    final achieved = netAmount;
    final cost = goal.cost;

    if (cost.isNegative) {
      return -1.0;
    }

    if (cost == 0) {
      // Can't divide by zero, so:
      if (achieved == 0) {
        return 1; // Return one if achieved is also zero (100% completion)
      } else if (achieved > 0) {
        // Let's assume anything toward a zero-cost goal is infinitely completed
        return double.infinity;
      } else {
        return 0;
      }
    }

    return achieved / cost;
  }

  String? getStatus({double? totalBalance}) {
    final amountRemaining = totalBalance ?? (goal.cost - netAmount);
    final formattedAmount = formatAmount(amountRemaining);

    String? helperText;

    if (amountRemaining.isNegative) {
      // substring(1) to remove the minus symbol
      helperText = "You're \$${formattedAmount.substring(1)} past your goal!";
    } else if (amountRemaining == 0) {
      helperText = "You've met your goal! Congrats!";
    } else {
      helperText = '\$$formattedAmount remaining';
    }

    return helperText;
  }
}

/// The ideal way to retrieve a category from the database.
/// Includes the net amount of money put into a category.
class CategoryWithAmount extends ContainerWithAmount {
  /// The database category.
  final Category category;

  @override
  Category get object => category;

  @override
  String get objectId => category.id;

  CategoryWithAmount({
    required this.category,
    required super.expenses,
    required super.income,
  });

  /// Get the remaining amount that can be used in a category over a certain
  /// time.
  ///
  /// The amount field was already retrieved based on the category's relative
  /// date range, so it's subtracted from the category's balance to get the
  /// remaining amount.
  double? get remainingAmount {
    if (category.balance == 0 || category.balance == null) return null;

    // Since the amount is signed, where negative is spent money, we add the
    // balance to the total.
    return category.balance! + netAmount;
  }
}

class AccountWithAmount extends ContainerWithAmount {
  final Account account;

  @override
  Account get object => account;

  @override
  String get objectId => account.id;

  AccountWithAmount({
    required this.account,
    required super.expenses,
    required super.income,
  });
}

class HydratedTransaction {
  final Transaction transaction;
  final CategoryWithAmount? categoryPair;
  final AccountWithAmount? accountPair;
  final GoalWithAmount? goalPair;

  HydratedTransaction({
    required this.transaction,
    this.categoryPair,
    this.accountPair,
    this.goalPair,
  });

  @override
  int get hashCode =>
      transaction.id.hashCode ^
      categoryPair.hashCode ^
      accountPair.hashCode ^
      goalPair.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydratedTransaction &&
          transaction.id == other.transaction.id &&
          categoryPair == other.categoryPair &&
          accountPair == other.accountPair &&
          goalPair == other.goalPair;
}

/// An object to easily transport a combination of Query object and two
/// Expressions that represent an amount of income and expense.
typedef QueryWithSums =
    ({
      JoinedSelectStatement query,
      Expression<double> income,
      Expression<double> expenses,
    });

/// Used to hold two expressions representing the expenses and income from
/// the database
typedef TransactionSumPair =
    ({Expression<double> expenses, Expression<double> income});

extension CategoriesExtension on Category {
  DateTime? getNextResetDate({DateTime? fromDate}) {
    DateTime now = fromDate ?? DateTime.now();
    DateTime nextReset;

    switch (resetIncrement) {
      case CategoryResetIncrement.daily:
        // Next day at midnight
        nextReset = DateTime(now.year, now.month, now.day + 1);
        break;
      case CategoryResetIncrement.weekly:
        // Next Monday at midnight
        nextReset = DateTime(now.year, now.month, now.day + (8 - now.weekday));
        break;
      case CategoryResetIncrement.monthly:
        // First day of next month
        if (now.month == 12) {
          nextReset = DateTime(now.year + 1, 1, 1);
        } else {
          nextReset = DateTime(now.year, now.month + 1, 1);
        }
        break;
      case CategoryResetIncrement.yearly:
        // First day of next year
        nextReset = DateTime(now.year + 1, 1, 1);
        break;
      default:
        return null;
    }

    return nextReset;
  }

  String getTimeUntilNextReset({DateTime? fromDate}) {
    final now = fromDate ?? DateTime.now();
    final nextReset = getNextResetDate(fromDate: fromDate);

    if (nextReset == null) return '';

    Duration timeLeft = nextReset.difference(now);
    int days = timeLeft.inDays;
    int hours = timeLeft.inHours % 24;
    int minutes = timeLeft.inMinutes % 60;

    if (timeLeft.isNegative) return 'Now';

    if (days > 30) {
      int months = days ~/ 30;
      return months == 1 ? 'a month' : '$months months';
    } else if (days >= 7) {
      int weeks = days ~/ 7;
      return weeks == 1 ? 'a week' : '$weeks weeks';
    } else if (days > 0) {
      return days == 1 ? 'a day' : '$days days';
    } else if (hours > 0) {
      return hours == 1 ? 'an hour' : '$hours hours';
    } else {
      return minutes == 1 ? 'a minute' : '$minutes minutes';
    }
  }
}

extension TransactionExtensions on Transaction {
  String formatDate() {
    return DateFormat('MM/dd/yyyy').format(date);
  }
}

class ColorConverter extends TypeConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromSql(int fromDb) => Color(fromDb);

  @override
  int toSql(Color value) => value.toARGB32();
}

class DateTextConverter extends TypeConverter<DateTime, String> {
  const DateTextConverter();

  @override
  DateTime fromSql(String fromDb) => formatter.parseStrict(fromDb);

  @override
  String toSql(DateTime value) => formatter.format(value);
}

class DateTimeTextConverter extends TypeConverter<DateTime, String> {
  const DateTimeTextConverter();

  @override
  DateTime fromSql(String fromDb) => DateTime.parse(fromDb);

  @override
  String toSql(DateTime value) => value.toIso8601String();
}
