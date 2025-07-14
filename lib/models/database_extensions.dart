import 'dart:math';

import 'package:budget/appui/goals/view_goal.dart';
import 'package:budget/appui/transactions/view_transaction.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/enums.dart';
import 'package:budget/utils/ui.dart';
import 'package:budget/utils/validators.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

final formatter = DateFormat('yyyy-MM-dd');

int genColor() =>
    Color((Random().nextDouble() * 0xFFFFFF).toInt()).withAlpha(255).toARGB32();

abstract class Tileable<T extends Tileable<T>> {
  String get id;

  final void Function(bool? isSelected, T adapterInstance) onMultiselect;

  Tileable({required this.onMultiselect});

  Widget getTile(BuildContext context, {bool isMultiselect, bool isSelected});
}

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

class TransactionTileableAdapter extends Tileable<TransactionTileableAdapter> {
  final Transaction _transaction;

  @override
  String get id => _transaction.id;

  TransactionTileableAdapter(this._transaction, {required super.onMultiselect});

  @override
  Widget getTile(
    BuildContext context, {
    bool isMultiselect = false,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);

    Widget leadingWidget;

    // Use an alternate color scheme if the transaction is either in the
    // future or archived to tell the user that the transaction is
    // ephemeral
    final isInFuture = _transaction.date.isAfter(DateTime.now());
    final isAlternateColorScheme = _transaction.isArchived || isInFuture;

    final containerColor =
        isAlternateColorScheme
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.secondaryContainer;

    final onColor =
        isAlternateColorScheme
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSecondaryContainer;

    if (isMultiselect) {
      leadingWidget = SizedBox(
        height: 48,
        width: 48,
        child: Checkbox(
          value: isSelected,
          onChanged: (value) => onMultiselect(value, this),
        ),
      );
    } else {
      leadingWidget = IconButton(
        icon:
            (_transaction.type == TransactionType.expense)
                ? Icon(Icons.remove_circle, color: onColor)
                : Icon(Icons.add_circle, color: onColor),
        onPressed: () => onMultiselect(true, this),
      );
    }

    String subtitle = _transaction.formatDate();

    if (isInFuture) {
      subtitle += ' (Future)';
    }

    if (_transaction.isArchived) {
      subtitle += ' (Archived)';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
      horizontalTitleGap: 4,
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 125),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: leadingWidget,
      ),
      title: Text(
        // Formats as "$500.00: Title of the Budget"
        "${"\$${formatAmount(_transaction.amount, truncateIfWhole: false)}"}: \"${_transaction.title}\"",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle),
      onTap: () async {
        var hydratedTransaction = await context
            .read<AppDatabase>()
            .transactionDao
            .hydrateTransaction(_transaction);

        if (!context.mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    ViewTransaction(transactionData: hydratedTransaction),
          ),
        );
      },
      onLongPress: () => showOptionsDialog(context, _transaction),
      trailing: IconButton(
        icon: Icon(Icons.more_vert, color: onColor),
        onPressed: () => showOptionsDialog(context, _transaction),
      ),
      tileColor: containerColor,
      textColor: onColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TransactionTileableAdapter && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}

class GoalTileableAdapter extends Tileable<GoalTileableAdapter> {
  final GoalWithAmount _goalPair;

  @override
  String get id => _goalPair.goal.id;

  double get amount => _goalPair.netAmount;
  Goal get goal => _goalPair.goal;

  GoalTileableAdapter(this._goalPair, {required super.onMultiselect});

  @override
  Widget getTile(
    BuildContext context, {
    bool isMultiselect = false,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);

    final percentage = _goalPair.calculatePercentage();
    final isFinished = percentage >= 1 || goal.isArchived;

    final containerColor =
        isFinished
            ? theme.colorScheme.surfaceContainerHigh
            : theme.colorScheme.secondaryContainer;

    final onColor =
        isFinished
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSecondaryContainer;

    // Decide whether to show the checkmark with the leading progress indicator
    final progressIndicator = CircularProgressIndicator(
      value: _goalPair.calculatePercentage(),
      backgroundColor: theme.colorScheme.onSecondaryContainer.withAlpha(68),
      strokeCap: StrokeCap.round,
    );

    Widget leadingWidget;

    if (isFinished) {
      leadingWidget = Stack(
        alignment: Alignment.center,
        children: [
          progressIndicator,
          Icon(Icons.check, color: theme.colorScheme.primary),
        ],
      );
    } else {
      leadingWidget = progressIndicator;
    }

    return ListTile(
      title: Text(goal.name),
      leading: leadingWidget,
      subtitle: Text('\$${formatAmount(amount)}/\$${formatAmount(goal.cost)}'),
      tileColor: containerColor,
      textColor: onColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GoalViewer(initialGoalPair: _goalPair),
            ),
          ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GoalTileableAdapter && id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
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
