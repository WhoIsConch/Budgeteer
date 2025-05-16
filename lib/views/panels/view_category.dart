import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/views/components/viewer_screen.dart';
import 'package:budget/views/panels/manage_category.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CategoryViewer extends StatelessWidget {
  final CategoryWithAmount categoryPair;

  const CategoryViewer({super.key, required this.categoryPair});

  Category get category => categoryPair.category;

  List<ObjectPropertyData> _getProperties() {
    final List<ObjectPropertyData> properties = [
      ObjectPropertyData(
        icon: Icons.schedule,
        title: 'Reset increment',
        description: category.resetIncrement.capitalizedName(),
      ),
    ];

    if (category.resetIncrement != CategoryResetIncrement.never) {
      final nextReset = category.getNextResetDate();
      if (nextReset != null) {
        final nextResetString = DateFormat(
          DateFormat.YEAR_ABBR_MONTH_DAY,
        ).format(nextReset);
        properties.add(
          ObjectPropertyData(
            icon: Icons.autorenew,
            title: 'Next reset',
            description:
                '${category.getTimeUntilNextReset()} | $nextResetString',
          ),
        );
      }
    }

    return properties;
  }

  @override
  Widget build(BuildContext context) {
    final formattedProgress = formatAmount(
      categoryPair.amount?.abs() ?? 0,
      round: true,
    );
    final formattedTotal = formatAmount(category.balance ?? 0, round: true);
    final formattedRemaining = formatAmount(
      categoryPair.remainingAmount ?? 0,
      round: true,
    );

    final Widget header;

    if (category.balance != null) {
      header = ProgressOverviewHeader(
        title: category.name,
        description: '\$$formattedRemaining remaining',
        insidePrimary: '\$$formattedProgress',
        insideSecondary: '\$$formattedProgress/\$$formattedTotal',
        progress: (categoryPair.amount?.abs() ?? 0) / (category.balance ?? 1),
      );
    } else {
      header = TextOverviewHeader(
        title: category.name,
        description: 'Resets ${category.getTimeUntilNextReset()}',
      );
    }
    return ViewerScreen(
      title: 'View category',
      onEdit:
          () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ManageCategoryDialog(category: categoryPair),
            ),
          ),
      header: header,
      body: ObjectPropertiesList(properties: _getProperties()),
    );
  }
}
