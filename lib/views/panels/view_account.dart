import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/views/components/viewer_screen.dart';
import 'package:budget/views/panels/manage_account.dart';
import 'package:flutter/material.dart';

class AccountViewer extends StatelessWidget {
  final AccountWithTotal accountPair;

  const AccountViewer({super.key, required this.accountPair});

  Account get account => accountPair.account;
  double get total => accountPair.total;

  List<ObjectPropertyData> _getProperties() {
    // Bruh I don't think accounts actually have any useful properties
    final List<ObjectPropertyData> properties = [];

    return properties;
  }

  @override
  Widget build(BuildContext context) {
    Color? textColor;
    String prefix = '';

    final title = formatAmount(total.abs(), exact: true);
    final description = account.name;

    if (total.isNegative) {
      prefix = '-';
      textColor = Theme.of(context).colorScheme.error;
    }

    return ViewerScreen(
      title: 'View Account',
      onEdit:
          () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ManageAccountForm(initialAccount: accountPair),
            ),
          ),
      header: TextOverviewHeader(
        title: '$prefix\$$title',
        description: description,
        textColor: textColor,
      ),
      body: ObjectPropertiesList(properties: _getProperties()),
    );
  }
}
