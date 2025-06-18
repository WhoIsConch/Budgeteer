import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/appui/components/viewer_screen.dart';
import 'package:budget/appui/transactions/manage_transaction.dart';
import 'package:budget/appui/categories/view_category.dart';
import 'package:budget/appui/goals/view_goal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ViewTransaction extends StatelessWidget {
  final HydratedTransaction transactionData;

  const ViewTransaction({super.key, required this.transactionData});

  Transaction get transaction => transactionData.transaction;
  Category? get category => transactionData.categoryPair?.category;
  Goal? get goal => transactionData.goalPair?.goal;
  Account? get account => transactionData.accountPair?.account;

  List<ObjectPropertyData> _getProperties(BuildContext context) {
    final List<ObjectPropertyData> properties = [
      ObjectPropertyData(
        icon: Icons.calendar_today,
        title: 'Date',
        description: DateFormat(
          DateFormat.YEAR_ABBR_MONTH_DAY,
        ).format(transaction.date),
      ),
    ];

    if (category != null) {
      properties.add(
        ObjectPropertyData(
          icon: Icons.category,
          title: 'Category',
          description: category!.name,
          action: () async {
            final categoryPair = await context
                .read<AppDatabase>()
                .categoryDao
                .getCategoryById(category!.id);

            if (categoryPair == null) return;
            if (!context.mounted) return;

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryViewer(categoryPair: categoryPair),
              ),
            );
          },
        ),
      );
    }

    if (goal != null) {
      properties.add(
        ObjectPropertyData(
          icon: Icons.flag,
          title: 'Goal',
          description: goal!.name,
          action: () async {
            final fulfillmentAmount =
                await context
                    .read<AppDatabase>()
                    .goalDao
                    .getGoalFulfillmentAmount(goal!)
                    .first;

            if (fulfillmentAmount == null) return;
            if (!context.mounted) return;

            Navigator.of(context).push(
              MaterialPageRoute(
                builder:
                    (_) => GoalViewer(
                      initialGoalPair: GoalWithAchievedAmount(
                        goal: goal!,
                        achievedAmount: fulfillmentAmount,
                      ),
                    ),
              ),
            );
          },
        ),
      );
    }

    if (account != null) {
      properties.add(
        ObjectPropertyData(
          icon: Icons.account_balance,
          title: 'Account',
          description: account!.name,
        ),
      );
    }

    if (transaction.notes != null && transaction.notes!.isNotEmpty) {
      properties.add(
        ObjectPropertyData(
          icon: Icons.notes,
          title: 'Notes',
          description: transaction.notes!,
        ),
      );
    }

    return properties;
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScreen(
      onEdit:
          () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (_) => ManageTransactionPage(initialTransaction: transaction),
            ),
          ),
      onArchive: () {
        if (transaction.isArchived) {
          final db = context.read<AppDatabase>();
          db.transactionDao.setTransactionsArchived([transaction.id], false);
        } else {
          final deletionManager = DeletionManager(context);
          deletionManager.stageObjectsForArchival<Transaction>([
            transaction.id,
          ]);
        }
        Navigator.of(context).pop();
      },
      onDelete: () {
        final deletionManager = DeletionManager(context);
        deletionManager.stageObjectsForDeletion<Transaction>([transaction.id]);
        Navigator.of(context).pop();
      },
      title: 'View transaction',
      header: TextOverviewHeader.dollarTitle(
        context,
        amount: transaction.amount,
        description: transaction.title,
        isNegative: transaction.type == TransactionType.expense,
      ),
      properties: ObjectPropertiesList(properties: _getProperties(context)),
    );
  }
}
