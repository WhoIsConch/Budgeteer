import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/views/panels/manage_transaction.dart';
import 'package:flutter/material.dart';

void showOptionsDialog(BuildContext context, Transaction transaction) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text("Edit"),
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
            leading: const Icon(Icons.delete),
            title: const Text("Delete"),
            onTap: () {
              DeletionManager(
                context,
              ).stageObjectsForDeletion<Transaction>([transaction.id]);
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}
