import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';

class GoalWithAchievedAmount {
  final Goal goal;
  final double achievedAmount;

  GoalWithAchievedAmount({required this.goal, this.achievedAmount = 0});

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
  // so we just need to add it to the category.
  // We add it because the database call returns negative numbers for expenses and
  // positive for income, so the balance in a category would increase if you add
  // an income transaction to a category.
  double? get remainingAmount =>
      category.balance == null ? null : category.balance! + (amount ?? 0);

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

class HydratedTransaction {
  final Transaction transaction;
  final CategoryWithAmount? category;
  final Account? account;
  final Goal? goal;

  HydratedTransaction({
    required this.transaction,
    this.category,
    this.account,
    this.goal,
  });

  @override
  int get hashCode =>
      transaction.id.hashCode ^
      category.hashCode ^
      account.hashCode ^
      goal.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HydratedTransaction &&
          category == other.category &&
          account == other.account &&
          goal == other.goal;
}
