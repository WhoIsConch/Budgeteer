import 'package:budget/services/app_database.dart';

class GoalWithAchievedAmount {
  final Goal goal;
  final double? achievedAmount;

  GoalWithAchievedAmount({
    required this.goal,
    this.achievedAmount,
  });
}

class CategoryWithAmount {
  final Category category;
  final double? amount;

  CategoryWithAmount({required this.category, this.amount});
}
