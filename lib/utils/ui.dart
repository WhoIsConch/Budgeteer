import 'package:budget/appui/transactions/manage_transfer.dart';
import 'package:budget/services/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/appui/transactions/manage_transaction.dart';
import 'package:flutter/material.dart';

void showOptionsDialog(BuildContext context, Transaction transaction) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      final deletionManager = DeletionManager(context);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ManageTransactionPage(
                        initialTransaction: transaction,
                      ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('Archive'),
            onTap: () {
              deletionManager.stageObjectsForArchival<Transaction>([
                transaction.id,
              ]);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              deletionManager.stageObjectsForDeletion<Transaction>([
                transaction.id,
              ]);
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

void showTransferOptions(BuildContext context, Transfer transfer) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      final deletionManager = DeletionManager(context);

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          ManageTransferPage(initialTransfer: transfer),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('Archive'),
            onTap: () {
              deletionManager.stageObjectsForArchival<Transaction>([
                transfer.$1.id,
                transfer.$2.id,
              ]);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              deletionManager.stageObjectsForDeletion<Transaction>([
                transfer.$1.id,
                transfer.$2.id,
              ]);
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}
