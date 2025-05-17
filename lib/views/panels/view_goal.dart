import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/views/components/viewer_screen.dart';
import 'package:budget/views/panels/manage_goal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GoalViewer extends StatelessWidget {
  final GoalWithAchievedAmount goalPair;

  const GoalViewer({super.key, required this.goalPair});

  Goal get goal => goalPair.goal;

  List<ObjectPropertyData> _getProperties() {
    final List<ObjectPropertyData> properties = [
      ObjectPropertyData(
        icon: Icons.flag,
        title: 'Status',
        description: goal.isFinished ? 'Complete' : 'Incomplete',
      ),
    ];

    if (goal.dueDate != null) {
      properties.add(
        ObjectPropertyData(
          icon: Icons.date_range,
          title: 'Due by',
          description: DateFormat(
            DateFormat.YEAR_ABBR_MONTH_DAY,
          ).format(goal.dueDate!),
        ),
      );
    }

    if (goal.notes != null && goal.notes!.isNotEmpty) {
      properties.add(
        ObjectPropertyData(
          icon: Icons.notes,
          title: 'Notes',
          description: goal.notes!,
        ),
      );
    }

    return properties;
  }

  @override
  Widget build(BuildContext context) {
    final achieved = goalPair.achievedAmount;
    final total = goal.cost;

    String prefix = '';

    if (achieved.isNegative) {
      prefix = '-';
    }

    final formattedAchieved = formatAmount(achieved.abs(), round: true);
    final formattedTotal = formatAmount(total, round: true);

    return ViewerScreen(
      title: 'View goal',
      onEdit:
          () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ManageGoalPage(initialGoal: goalPair),
            ),
          ),
      onDelete: () {
        final deletionManager = DeletionManager(context);

        deletionManager.stageObjectsForDeletion<Goal>([goal.id]);

        Navigator.of(context).pop();
      },
      header: ProgressOverviewHeader(
        title: goal.name,
        description: goalPair.getStatus(),
        insidePrimary: '$prefix\$$formattedAchieved',
        insideSecondary: '$prefix\$$formattedAchieved/\$$formattedTotal',
        progress: achieved / total,
        foregroundColor: goal.color,
      ),
      body: ObjectPropertiesList(properties: _getProperties()),
    );
  }
}
