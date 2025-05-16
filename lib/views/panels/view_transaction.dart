import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/views/components/viewer_screen.dart';
import 'package:budget/views/panels/manage_transaction.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ViewTransaction extends StatelessWidget {
  final HydratedTransaction transactionData;

  const ViewTransaction({super.key, required this.transactionData});

  Transaction get transaction => transactionData.transaction;
  Category? get category => transactionData.category;
  Goal? get goal => transactionData.goal;
  Account? get account => transactionData.account;

  List<ObjectPropertyData> _getProperties() {
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
        ),
      );
    }

    if (goal != null) {
      properties.add(
        ObjectPropertyData(
          icon: Icons.flag,
          title: 'Goal',
          description: goal!.name,
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
    Color textColor;
    String prefix;

    final title = formatAmount(transaction.amount);
    final description = transaction.title;

    if (transaction.type == TransactionType.expense) {
      textColor = Theme.of(context).colorScheme.error;
      prefix = '-';
    } else {
      textColor = Colors.green.harmonizeWith(
        Theme.of(context).colorScheme.primary,
      );
      prefix = '+';
    }

    return ViewerScreen(
      onEdit:
          () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (_) => ManageTransactionPage(initialTransaction: transaction),
            ),
          ),
      onArchive: () {
        if (transaction.isArchived ?? false) {
          final transactionDao = context.read<TransactionDao>();
          transactionDao.setArchiveTransactions([transaction.id], false);
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
      header: TextOverviewHeader(
        title: '$prefix\$$title',
        description: description,
        textColor: textColor,
      ),
      body: ObjectPropertiesList(properties: _getProperties()),
    );
  }
}
