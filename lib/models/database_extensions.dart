import 'package:budget/services/app_database.dart';

class GoalWithAchievedAmount {
  final Goal goal;
  final double? achievedAmount;

  GoalWithAchievedAmount({required this.goal, this.achievedAmount});
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
