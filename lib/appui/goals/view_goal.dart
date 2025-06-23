import 'package:budget/appui/components/objects_list.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/appui/components/viewer_screen.dart';
import 'package:budget/appui/goals/manage_goal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GoalViewer extends StatefulWidget {
  final GoalWithAmount initialGoalPair;

  const GoalViewer({super.key, required this.initialGoalPair});

  @override
  State<GoalViewer> createState() => _GoalViewerState();
}

class _GoalViewerState extends State<GoalViewer> {
  List<ObjectPropertyData> _getProperties(
    BuildContext context,
    GoalWithAmount goalPair,
  ) {
    final goal = goalPair.goal;
    final percentage = goalPair.calculatePercentage();

    final List<ObjectPropertyData> properties = [];

    if (percentage >= 1 && !(goal.isArchived)) {
      properties.add(
        ObjectPropertyData(
          icon: Icons.flag,
          title: 'Goal completed!',
          description: 'Mark this goal as finished?',
          actionButtons: [
            PropertyAction(
              title: 'Finish',
              onPressed: () {
                final manager = DeletionManager(context);

                manager.stageObjectsForArchival<Goal>([goal.id]);
              },
            ),
          ],
        ),
      );
    } else {
      properties.add(
        ObjectPropertyData(
          icon: Icons.flag,
          title: 'Status',
          description: goal.isArchived ? 'Complete' : 'Incomplete',
        ),
      );
    }

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
    final db = context.read<AppDatabase>();

    return StreamBuilder<GoalWithAmount>(
      initialData: widget.initialGoalPair,
      stream: db.goalDao.watchGoalById(widget.initialGoalPair.goal.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Align(
            alignment: Alignment.center,
            child: CircularProgressIndicator(),
          );
        }
        final goalPair = snapshot.data!;
        final goal = goalPair.goal;

        final achieved = goalPair.netAmount;
        final total = goal.cost;

        String prefix = '';

        if (achieved.isNegative) {
          prefix = '-';
        }

        final formattedAchieved = formatAmount(achieved.abs(), round: true);
        String formattedTotal = formatAmount(total, exact: true);

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
            insideSecondary: '\$$formattedTotal',
            progress: achieved / total,
            foregroundColor: goal.color,
          ),
          properties: ObjectPropertiesList(
            properties: _getProperties(context, goalPair),
          ),
          body: SizedBox(
            height: 300,
            child: ObjectsList<TransactionTileableAdapter>(
              showBackground: false,
              filters: [
                GoalFilter([goalPair]),
              ],
            ),
          ),
        );
      },
    );
  }
}
