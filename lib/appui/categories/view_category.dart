import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/appui/components/viewer_screen.dart';
import 'package:budget/appui/categories/manage_category.dart';
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
        description: toBeginningOfSentenceCase(category.resetIncrement.name),
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
    final Widget header;

    if (category.balance != null && category.balance != 0) {
      double progress = categoryPair.netAmount * -1;
      double remaining = categoryPair.remainingAmount ?? 0;
      double total = category.balance!;
      String remainingText;

      final progressPrefix = progress < 0 ? '-' : '';

      final formattedProgress = formatAmount(progress.abs(), round: true);
      final formattedTotal = formatAmount(total, round: true);
      final formattedRemaining = formatAmount(remaining.abs(), round: true);

      if ((categoryPair.remainingAmount ?? 0) < 0) {
        remainingText = '\$$formattedRemaining over budget';
      } else {
        remainingText = '\$$formattedRemaining remaining';
      }

      double chartProgress;

      if (progress.isNegative) {
        chartProgress = 0;
      } else {
        chartProgress =
            (categoryPair.netAmount.abs()) / (category.balance ?? 1);
      }

      header = ProgressOverviewHeader(
        title: category.name,
        description: remainingText,
        insidePrimary: '$progressPrefix\$$formattedProgress',
        insideSecondary:
            '$progressPrefix\$$formattedProgress/\$$formattedTotal',
        progress: chartProgress,
      );
    } else {
      header = TextOverviewHeader.dollarTitle(
        context,
        amount: categoryPair.netAmount,
        description: category.name,
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
      properties: ObjectPropertiesList(properties: _getProperties()),
    );
  }
}
