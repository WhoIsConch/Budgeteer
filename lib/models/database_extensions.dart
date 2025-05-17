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
}

class HydratedTransaction {
  final Transaction transaction;
  final Category? category;
  final Account? account;
  final Goal? goal;

  HydratedTransaction({
    required this.transaction,
    this.category,
    this.account,
    this.goal,
  });
}
