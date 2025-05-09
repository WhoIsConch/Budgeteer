import 'package:budget/services/app_database.dart';

class GoalWithAchievedAmount {
  final Goal goal;
  final double? achievedAmount;

  GoalWithAchievedAmount({
    required this.goal,
    this.achievedAmount,
  });
}
