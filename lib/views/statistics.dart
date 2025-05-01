import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChartCalculationResult {
  final List<PieChartSectionData> sectionData;
  final List<ChartKeyItem> keyItems;
  final double totalAmount;
  final bool isEmpty;

  ChartCalculationResult({
    required this.sectionData,
    required this.keyItems,
    required this.totalAmount,
    required this.isEmpty,
  });
}

class ChartKeyItem extends StatelessWidget {
  const ChartKeyItem(
      {super.key,
      required this.color,
      required this.name,
      this.icon,
      required this.percent});

  final Color color;
  final String name;
  final int percent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 20,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        icon == null
            ? Padding(
                padding: const EdgeInsets.all(2.0),
                child: Container(
                  decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(6)),
                  child: const SizedBox(height: 18, width: 18),
                ),
              )
            : Icon(icon, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text("$percent%", style: textStyle),
      ],
    );
  }
}

/* 
  DropdownMenu getDateRangeDropdown() => DropdownMenu(
        expandedInsets: EdgeInsets.zero,
        initialSelection: dateRange,
        onSelected: (value) => setState(() => filterProvider.updateFilter(
            TransactionFilter<RelativeDateRange>(value as RelativeDateRange))),
        dropdownMenuEntries: RelativeDateRange.values
            .map(
              (e) => DropdownMenuEntry(
                label: e.name,
                value: e,
              ),
            )
            .toList(),
      );
*/

class VerticalTabButton extends StatelessWidget {
  final String text;
  final void Function() onPressed;
  final bool isSelected;

  const VerticalTabButton(
      {super.key,
      required this.text,
      required this.onPressed,
      this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor:
              isSelected ? Theme.of(context).colorScheme.surface : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: onPressed,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  static const estKeyItemHeight = 30;
  static const maxItems = 5;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  // I couldn't think of a better name for these so they are
  // typeIndex for the type of transaction and containerIndex
  // for the containers a transaction belongs to
  // In this case, goals, categories, and accounts are containers
  int typeIndex = 0;
  int containerIndex = 0;
  List<TransactionFilter> filters = [
    TransactionFilter<DateTimeRange>(RelativeDateRange.thisMonth.getRange())
  ];
  final List<String> _typeTabs = ["Income", "Expenses", "Cash Flow"];
  final List<String> _containerTabs = ["Category", "Goal", "Account"];

  late final TransactionDao _transactionDao;

  final chartCenterRadius = 60.0; // Don't let the text go beyond that radius

  @override
  void initState() {
    super.initState();

    _transactionDao = context.read<TransactionDao>();
  }

  List<Widget> _buildVerticalTabs(List<String> tabs, int selectedIndex,
          ValueChanged<int> onTabSelected) =>
      List.generate(
          _containerTabs.length,
          (index) => VerticalTabButton(
              text: tabs[index],
              isSelected: index == selectedIndex,
              onPressed: () => onTabSelected(index)));

  Future<ChartCalculationResult> _calculateChartData({
    required List<Category?> categories,
    required List<TransactionFilter> filters,
  }) async {
    double absTotal = 0;
    List<PieChartSectionData> sectionData = [];
    List<ChartKeyItem> keyItems = [];
    double otherSectionTotal = 0;

    TransactionType? typeFilter = filters
        .firstWhereOrNull((e) => e.value.runtimeType == TransactionType)
        ?.value;
    DateTimeRange? dateFilter = filters
        .firstWhereOrNull((e) => e.value.runtimeType == DateTimeRange)
        ?.value;

    List<Future<double?>> futures = [];
    for (final category in categories) {
      futures.add(_transactionDao
          .watchTotalAmount(
              nullCategory: category == null,
              category: category,
              type: typeFilter,
              dateRange: dateFilter)
          .first);
    }
    final totals = (await Future.wait(futures)).map((e) => e ?? 0).toList();

    absTotal = totals.sum;

    if (absTotal == 0) {
      return ChartCalculationResult(
          sectionData: [], keyItems: [], totalAmount: 0, isEmpty: true);
    }

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final total = totals[i];

      if (total == 0) continue;

      double percentage = (total.abs() / absTotal) * 100;

      final color = category?.color ?? Colors.grey[400]!;
      final name = category?.name ?? "Uncategorized";

      if (percentage < 2) {
        otherSectionTotal += total.abs();
      } else {
        sectionData.add(PieChartSectionData(
          value: total.abs(),
          radius: 36,
          showTitle: false,
          color: color,
        ));

        final keyItem = ChartKeyItem(
          color: color,
          name: name,
          percent: percentage.round(),
        );
        if (total > 0) {
          keyItems.insert(0, keyItem);
        } else {
          keyItems.add(keyItem);
        }
      }
    }

    if (otherSectionTotal != 0) {
      double percentage = (otherSectionTotal.abs() / absTotal.abs()) * 100;

      if (percentage >= 1) {
        sectionData.add(PieChartSectionData(
          value: otherSectionTotal,
          radius: 36,
          showTitle: false,
          color: Colors.grey,
        ));
        keyItems.add(ChartKeyItem(
            color: Colors.grey, name: "Other", percent: percentage.round()));
      }
    }

    return ChartCalculationResult(
      sectionData: sectionData,
      keyItems: keyItems,
      totalAmount: absTotal,
      isEmpty: sectionData.isEmpty,
    );
  }

  Widget _getPieChart(ChartCalculationResult data) {
    bool amountIsNegative = data.totalAmount < 0;
    String formattedAmount =
        formatAmount(data.totalAmount.abs(), round: true, exact: true);

    String amountString;

    if (amountIsNegative) {
      amountString = "-\$$formattedAmount";
    } else {
      amountString = "\$$formattedAmount";
    }

    return SizedBox(
      width: 200,
      height: 200,
      child: AspectRatio(
          aspectRatio: 1,
          child: Stack(children: [
            Center(
                child: SizedBox(
              width: (chartCenterRadius - 12) *
                  2, // To give it some padding and account for the fact that this is a radius and the text fits within the diameter
              child: AutoSizeText(amountString,
                  style: Theme.of(context).textTheme.headlineLarge,
                  maxLines: 1),
            )),
            PieChart(PieChartData(
                centerSpaceRadius: chartCenterRadius,
                sections: data.sectionData)),
          ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    String titleText = switch (typeIndex) {
      0 => "earning",
      1 => "spending",
      2 => "cash flow",
      _ => "invalid" // Shouldn't happen
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment
          .stretch, // Just for the text. Could be start aligned
      children: [
        Card(
          margin: EdgeInsets.zero,
          color:
              getAdjustedColor(context, Theme.of(context).colorScheme.surface),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: StreamBuilder<List<Category>>(
                      stream: context.read<AppDatabase>().watchCategories(),
                      builder: (context, categorySnapshot) {
                        if (categorySnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !categorySnapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (categorySnapshot.hasError) {
                          return Center(
                              child: Text(
                                  'Error loading categories: ${categorySnapshot.error}'));
                        }
                        if (!categorySnapshot.hasData ||
                            categorySnapshot.data!.isEmpty) {
                          return Center(
                              child: Text("No categories available."));
                        }

                        final availableCategories = categorySnapshot.data!;
                        final categoriesWithNull = [
                          ...availableCategories,
                          null
                        ];

                        return FutureBuilder<ChartCalculationResult>(
                            future: _calculateChartData(
                                categories: categoriesWithNull,
                                filters: filters),
                            builder: (context, dataSnapshot) {
                              if (dataSnapshot.hasError) {
                                return Center(
                                    child: Text(
                                        "Unable to calculate chart values"));
                              } else if (!dataSnapshot.hasData ||
                                  dataSnapshot.data!.isEmpty) {
                                return Center(
                                    child: Text(
                                        "No data. Try changing your filters"));
                              }

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Your $titleText",
                                    textAlign: TextAlign.left,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  const SizedBox(height: 8.0),
                                  _getPieChart(dataSnapshot.data!),
                                  SizedBox(height: 12.0),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxHeight:
                                            (StatisticsPage.estKeyItemHeight *
                                                    StatisticsPage.maxItems)
                                                .toDouble()),
                                    child: ListView(
                                        shrinkWrap: true,
                                        children: dataSnapshot.data!.keyItems),
                                  ),
                                ],
                              );
                            });
                      }),
                ),
              ),
              IntrinsicWidth(
                  child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._buildVerticalTabs(_typeTabs, typeIndex,
                          (index) => setState(() => typeIndex = index)),
                      Divider(),
                      ..._buildVerticalTabs(_containerTabs, containerIndex,
                          (index) => setState(() => containerIndex = index)),
                    ]),
              ))
            ],
          ),
        ),
      ],
    );
  }
}
