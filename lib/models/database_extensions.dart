import 'dart:math';

import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final formatter = DateFormat('yyyy-MM-dd');

int genColor() =>
    Color((Random().nextDouble() * 0xFFFFFF).toInt()).withAlpha(255).toARGB32();

class GoalWithAchievedAmount {
  final Goal goal;
  final double achievedAmount;

  GoalWithAchievedAmount({required this.goal, this.achievedAmount = 0});

  double calculatePercentage() {
    final achieved = achievedAmount;
    final cost = goal.cost;

    if (cost.isNegative) {
      return -1.0;
    }

    if (cost == 0) {
      // Can't divide by zero, so:
      if (achieved == 0) {
        return 1; // Return one if achieved is also zero (100% completion)
      } else if (achieved > 0) {
        return double
            .infinity; // Let's assume anything toward a zero-cost goal is infinitely completed
      } else {
        return 0;
      }
    }

    return achieved / cost;
  }

  String? getStatus({double? totalBalance}) {
    final amountRemaining = totalBalance ?? (goal.cost - achievedAmount);
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

  @override
  int get hashCode => goal.id.hashCode ^ achievedAmount.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalWithAchievedAmount &&
          runtimeType == other.runtimeType &&
          goal.id == other.goal.id &&
          achievedAmount == other.achievedAmount;
}

class CategoryWithAmount {
  final Category category;
  final double? amount;

  CategoryWithAmount({required this.category, this.amount});

  // Get the remaining amount that can be used in a category over a certain time
  // The amount field was already grabbed with the relative date range in mind,
  // so we subtract it from the category balance to get remaining amount.
  // This gives us how much budget is remaining in the category.
  double? get remainingAmount {
    if (amount == null || category.balance == 0) return null;

    return category.balance! - amount!;
  }

  @override
  int get hashCode => category.id.hashCode ^ amount.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryWithAmount &&
          runtimeType == other.runtimeType &&
          category.id == other.category.id &&
          amount == other.amount;
}

class AccountWithTotal {
  final Account account;
  final double total;

  AccountWithTotal({required this.account, this.total = 0});

  @override
  int get hashCode => account.id.hashCode ^ total.hashCode;

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
        other is AccountWithTotal &&
            runtimeType == other.runtimeType &&
            account.id == other.account.id &&
            total == other.total;
  
}

class HydratedTransaction {
  final Transaction transaction;
  final CategoryWithAmount? categoryPair;
  final AccountWithTotal? accountPair;
  final GoalWithAchievedAmount? goalPair;

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

class QueryWithSum {
  final JoinedSelectStatement query;
  final Expression<double> sum;

  QueryWithSum(this.query, this.sum);
}

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
