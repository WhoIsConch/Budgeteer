import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';

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

class HydratedTransaction {
  final Transaction transaction;
  final CategoryWithAmount? category;
  final Account? account;
  final GoalWithAchievedAmount? goal;

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
          transaction.id == other.transaction.id &&
          category == other.category &&
          account == other.account &&
          goal == other.goal;
}
