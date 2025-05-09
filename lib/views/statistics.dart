import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/models/data.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:collection/collection.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    const textStyle = TextStyle(
      fontSize: 18,
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
      // TODO: Implement this functionality.
      // These temporarily are disabled until goals and accounts are actually
      // added.
      onPressed: ["Goal", "Account"].contains(text) ? null : onPressed,
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

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late TransactionProvider _filterProvider;
  final TextEditingController _rangeController = TextEditingController();

  DateTimeRange? get currentDateRange =>
      _filterProvider.getFilterValue<DateTimeRange>();

  void pickDateRange({DateTimeRange? initialRange}) async {
    DateTimeRange? newRange = await showDateRangePicker(
        context: context,
        initialDateRange: initialRange,
        firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 100)));

    if (newRange == null) return;
    _filterProvider.updateFilter<DateTimeRange>(TransactionFilter(newRange));
  }

  DropdownMenu getDateRangeDropdown() {
    List<DropdownMenuEntry<DateTimeRange?>> entries = RelativeDateRange.values
        .map((e) => DropdownMenuEntry<DateTimeRange?>(
            value: e.getRange(), label: e.name))
        .toList();

    RelativeDateRange? selectedRelRange =
        RelativeDateRange.values.firstWhereOrNull(
      (element) =>
          element.getRange() ==
          (currentDateRange ?? RelativeDateRange.today.getRange()),
    );

    if (selectedRelRange != null) {
      _rangeController.text = selectedRelRange.name;
    } else {
      // This means a custom range
      _rangeController.text = currentDateRange!.asString();
    }

    return DropdownMenu(
      controller: _rangeController,
      expandedInsets: EdgeInsets.zero,
      initialSelection: currentDateRange,
      onSelected: (range) async {
        if (range == null) {
          pickDateRange(initialRange: currentDateRange);
        } else {
          setState(() => _filterProvider
              .updateFilter(TransactionFilter<DateTimeRange>(range)));
        }
      },
      dropdownMenuEntries: entries,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _filterProvider = context.watch<TransactionProvider>();

    // This should really only be applicable at the beginning
    // but if for any reason our datetimerange becomes null this is a nice
    // failsafe to make sure everything doesn't break
    // (we have some suspicious type safety usage in getDateRangeDropdown)
    if (_filterProvider.getFilterValue<DateTimeRange>() == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _filterProvider.updateFilter<DateTimeRange>(
              TransactionFilter(RelativeDateRange.today.getRange())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(children: [
        Row(
          children: [
            Expanded(child: getDateRangeDropdown()),
            const SizedBox(width: 4),
            IconButton(
                iconSize: 32,
                icon: const Icon(Icons.date_range),
                onPressed: () => pickDateRange(initialRange: currentDateRange))
          ],
        ),
        const SizedBox(height: 8.0), // Bottom padding
        const PieChartCard(),
        const SizedBox(height: 8.0),
        // const LineChartCard(),
        const SpendingBarChart(),
        const SizedBox(height: 60) // To give the FAB somewhere to go
      ]),
    );
  }
}

class PieChartCard extends StatefulWidget {
  const PieChartCard({super.key});

  static const estKeyItemHeight = 30;
  static const maxItems = 5;

  @override
  State<PieChartCard> createState() => _PieChartCardState();
}

Widget errorInset(BuildContext context, String text) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.warning_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
        Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150)))
      ]),
    );

class _PieChartCardState extends State<PieChartCard> {
  // I couldn't think of a better name for these so they are
  // typeIndex for the type of transaction and containerIndex
  // for the containers a transaction belongs to
  // In this case, goals, categories, and accounts are containers
  int typeIndex = 0;
  int containerIndex = 0;
  final List<String> _typeTabs = ["Expenses", "Income", "Net"];
  final List<String> _containerTabs = ["Category", "Goal", "Account"];

  late final TransactionDao _transactionDao;
  late TransactionProvider _filtersProvider;

  final chartCenterRadius = 60.0; // Don't let the text go beyond that radius

  @override
  void initState() {
    super.initState();

    // Post-frame callback so the widget is fully built before
    // relying on the context, which is frowned upon
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _transactionDao = context.read<TransactionDao>();
      _filtersProvider = context.read<TransactionProvider>();
      TransactionType? currentType =
          _filtersProvider.getFilterValue<TransactionType>();

      setState(() {
        if (currentType != null) {
          typeIndex = currentType.value;
        } else {
          typeIndex = 2; // Cash Flow
        }
      });
    });
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
            dateRange: dateFilter,
            net: false,
          )
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
      final name = category?.name ?? "No category";

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
              child: AutoSizeText(
                  textAlign: TextAlign.center,
                  amountString,
                  style: Theme.of(context).textTheme.headlineLarge,
                  maxLines: 1),
            )),
            PieChart(PieChartData(
                centerSpaceRadius: chartCenterRadius,
                sections: data.sectionData)),
          ])),
    );
  }

  Widget _formattedErrorInset(String text) {
    // Same approach for "No categories" message
    return LayoutBuilder(builder: (context, constraints) {
      // TODO: Estimated center; make it exact
      final buttonsHeight = MediaQuery.of(context).size.height * 0.35;

      return SizedBox(height: buttonsHeight, child: errorInset(context, text));
    });
  }

  @override
  Widget build(BuildContext context) {
    _filtersProvider = context.watch<TransactionProvider>();

    String titleText = switch (typeIndex) {
      0 => "spending",
      1 => "earning",
      2 => "cash flow",
      _ => "invalid" // Shouldn't happen
    };

    return Card(
      margin: EdgeInsets.zero,
      color: getAdjustedColor(context, Theme.of(context).colorScheme.surface),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: StreamBuilder<List<CategoryWithAmount>>(
                  stream: context.read<AppDatabase>().watchCategories(),
                  builder: (context, categorySnapshot) {
                    if (categorySnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !categorySnapshot.hasData) {
                      return const SizedBox();
                    } else if (categorySnapshot.hasError) {
                      AppLogger().logger.e(
                          "Error loading categories: ${categorySnapshot.error}");
                      return _formattedErrorInset(
                          'Error loading categories: ${categorySnapshot.error}');
                    } else if (!categorySnapshot.hasData ||
                        categorySnapshot.data!.isEmpty) {
                      return _formattedErrorInset("No categories");
                    }

                    final availableCategories =
                        categorySnapshot.data!.map((ca) => ca.category);
                    final categoriesWithNull = [...availableCategories, null];

                    return FutureBuilder<ChartCalculationResult>(
                        future: _calculateChartData(
                            categories: categoriesWithNull,
                            filters: _filtersProvider.filters),
                        builder: (context, dataSnapshot) {
                          // These error widgets should be centered in the row vertically.
                          if (dataSnapshot.hasError) {
                            return _formattedErrorInset(
                                "Something went wrong. Try again later");
                          } else if (!dataSnapshot.hasData ||
                              dataSnapshot.data!.isEmpty) {
                            return _formattedErrorInset("No data");
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Your $titleText",
                                textAlign: TextAlign.left,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8.0),
                              _getPieChart(dataSnapshot.data!),
                              const SizedBox(height: 12.0),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxHeight: (PieChartCard.estKeyItemHeight *
                                            PieChartCard.maxItems)
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
                  ..._buildVerticalTabs(_typeTabs, typeIndex, (index) {
                    setState(() => typeIndex = index);

                    if (typeIndex == 0 || typeIndex == 1) {
                      _filtersProvider.updateFilter(
                          TransactionFilter<TransactionType>(
                              TransactionType.fromValue(typeIndex)));
                    } else {
                      _filtersProvider.removeFilter<TransactionType>();
                    }
                  }),
                  const Divider(),
                  ..._buildVerticalTabs(_containerTabs, containerIndex,
                      (index) => setState(() => containerIndex = index)),
                ]),
          ))
        ],
      ),
    );
  }
}

class LineChartCard extends StatefulWidget {
  const LineChartCard({super.key});

  @override
  State<LineChartCard> createState() => _LineChartCardState();
}

class _LineChartCardState extends State<LineChartCard> {
  late TransactionProvider _filtersProvider;

  DateTimeRange get dateRange =>
      _filtersProvider.getFilterValue<DateTimeRange>() ??
      RelativeDateRange.today.getRange();

  Future<LineChartCalculationData> _calculateData() async {
    // To get the necessary information for a bar chart, we need to get:
    // A range of dates/ranges in a date range (e.g. days, weeks, months)
    // Then, we need to get the amount of money spent and received in each
    // date or date range. For example, if the range was set to <10 days, we
    // can separate the chart based on days and collect transaction totals that
    // way. If the range is 10-45 days, we show the weekly results. If the
    // range is 45-365 days, we show a monthly breakdown. If >365, we show a
    // yearly breakdown. Hardly ideal.

    final int daysDifference = dateRange.duration.inDays;
    final TransactionDao transactionDao = context.read<TransactionDao>();

    AggregationLevel aggregationLevel = switch (daysDifference) {
      <= 90 => AggregationLevel.daily,
      <= 365 => AggregationLevel.weekly,
      _ => AggregationLevel.monthly,
    };

    final List<FinancialDataPoint> points = await transactionDao
        .getAggregatedRangeData(dateRange, aggregationLevel);

    List<FlSpot> expenseSpots = [];
    List<FlSpot> incomeSpots = [];
    List<String> xTitles = []; // Date Ranges

    for (var i = 0; i < points.length; i++) {
      final point = points[i];

      // Add the expense and income spot data
      if (point.spending != 0) {
        expenseSpots.add(FlSpot(i.toDouble(), point.spending));
      }
      if (point.income != 0) {
        incomeSpots.add(FlSpot(i.toDouble(), point.income));
      }

      // Decide on x-axis titles for the dates
      switch (aggregationLevel) {
        case AggregationLevel.daily:
          // Use dateRange.start since the start and end dates should be the same
          xTitles.add(DateFormat.Md().format(point.dateRange.start));
          break;
        case AggregationLevel.weekly:
          final String firstDate =
              DateFormat.Md().format(point.dateRange.start);
          final String lastDate = DateFormat.Md().format(point.dateRange.end);

          xTitles.add("$firstDate–$lastDate");
          break;
        case _:
          xTitles.add(DateFormat.MMM().format(point.dateRange.start));
          break;
      }
    }

    return LineChartCalculationData(
        expenseSpots, incomeSpots, xTitles, xTitles.isEmpty);
  }

  LineChartBarData _getChartBarData(List<FlSpot> spots, Color color) =>
      LineChartBarData(
          isStrokeCapRound: true,
          isCurved: true,
          curveSmoothness: 0.15,
          barWidth: 4,
          color: color.harmonizeWith(Theme.of(context).colorScheme.primary),
          spots: spots);

  double _calculateYAxisInterval(double minValue, double maxValue) {
    double range = maxValue - minValue;

    return range / 4;
  }

  Widget _getLineChart(LineChartCalculationData data) {
    final maxExpense = data.expenseSpots.fold(0.0, (l, n) => max(l, n.y));
    final maxIncome = data.incomeSpots.fold(0.0, (l, n) => max(l, n.y));
    final minExpense = data.expenseSpots.fold(0.0, (l, n) => min(l, n.y));
    final minIncome = data.incomeSpots.fold(0.0, (l, n) => min(l, n.y));

    final maxAmount = max(maxExpense, maxIncome);
    final minAmount = min(minExpense, minIncome);

    return LineChart(LineChartData(
        titlesData: FlTitlesData(
            // Fucking useless and unreasonably verbose way to describe titles on a chart
            leftTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    interval: _calculateYAxisInterval(minAmount, maxAmount),
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) {
                      return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text("\$${value.toInt()}"));
                    })),
            bottomTitles: AxisTitles(
                // X axis are stuck here since they use line chart calculation data
                sideTitles: SideTitles(
              reservedSize: 36,
              showTitles: true,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Transform.rotate(
                    angle: -45 * 3.14 / 180,
                    child: Text(data.xTitles[value.toInt()])),
              ),
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles()),
            rightTitles: const AxisTitles(sideTitles: SideTitles())),
        borderData: FlBorderData(show: false),
        // gridData: const FlGridData(show: false),
        lineBarsData: [
          _getChartBarData(data.expenseSpots, Colors.red),
          _getChartBarData(data.incomeSpots, Colors.green)
        ]));
  }

  @override
  Widget build(BuildContext context) {
    _filtersProvider = context.watch<TransactionProvider>();

    return AspectRatio(
      aspectRatio: 3 / 2,
      child: Card(
        margin: EdgeInsets.zero,
        color: getAdjustedColor(context, Theme.of(context).colorScheme.surface),
        child: Padding(
            padding: EdgeInsets.all(16.0),
            child: FutureBuilder(
              future: _calculateData(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return errorInset(context, "No data");
                } else if ((snapshot.data!.expenseSpots.length +
                        snapshot.data!.incomeSpots.length) <
                    3) {
                  // If there aren't enough spots the table will look pointless
                  return errorInset(context, "Insufficient data");
                } else if (snapshot.hasError) {
                  return errorInset(context, "Something went wrong");
                } else {
                  return _getLineChart(snapshot.data!);
                }
              },
            )),
      ),
    );
  }
}

class SpendingBarChart extends StatefulWidget {
  const SpendingBarChart({super.key});

  @override
  State<SpendingBarChart> createState() => _SpendingBarChartState();
}

class _SpendingBarChartState extends State<SpendingBarChart> {
  late TransactionProvider _filterProvider;

  String formatDateLabel(DateTimeRange range) {
    final formatter = DateFormat.Md();

    if (DateTime(range.start.year, range.start.month, range.start.day) ==
        DateTime(range.end.year, range.end.month, range.end.day)) {
      return formatter.format(range.start);
    } else if (range.start.month == range.end.month) {
      return '${formatter.format(range.start)}–${DateFormat('d').format(range.end)}';
    } else {
      // Different month range: "4/2-5/8"
      return '${formatter.format(range.start)}–${formatter.format(range.end)}';
    }
  }

  DateTimeRange get dateRange =>
      _filterProvider.getFilterValue<DateTimeRange>() ??
      RelativeDateRange.today.getRange();

  AxisTitles get noTitlesWidget =>
      const AxisTitles(sideTitles: SideTitles(showTitles: false));

  FlBorderData get chartBorderData {
    var borderSide = BorderSide(
      color: Theme.of(context).colorScheme.outlineVariant,
      width: 2.0,
    );

    return FlBorderData(
        show: true, border: Border(bottom: borderSide, top: borderSide));
  }

  BarChartGroupData createGroupData(FinancialDataPoint point, int x) =>
      BarChartGroupData(barsSpace: 4, x: x, barRods: [
        BarChartRodData(
            width: 12,
            toY: point.income,
            color: Colors.green
                .harmonizeWith(Theme.of(context).colorScheme.primary)),
        BarChartRodData(
            width: 12,
            toY: point.spending,
            color:
                Colors.red.harmonizeWith(Theme.of(context).colorScheme.primary))
      ]);

  Future<BarChartCalculationData> _calculateData() async {
    final int daysDifference = dateRange.duration.inDays;
    final TransactionDao transactionDao = context.read<TransactionDao>();

    AggregationLevel aggregationLevel = switch (daysDifference) {
      <= 90 => AggregationLevel.daily,
      <= 365 => AggregationLevel.weekly,
      _ => AggregationLevel.monthly,
    };

    List<FinancialDataPoint> points = await transactionDao
        .getAggregatedRangeData(dateRange, aggregationLevel);

    // Manage the list and filter it into data that we actually want to use
    int firstValidIndex = points.indexWhere((point) => point.isNotEmpty);

    if (firstValidIndex == -1) {
      points = [];
    } else {
      int lastValidIndex = points.lastIndexWhere((point) => point.isNotEmpty);
      points = points.sublist(firstValidIndex, lastValidIndex + 1);
    }

    final List<BarChartGroupData> data = [];
    List<String> xTitles = [];
    double minY = 0;
    double maxY = 0;
    int skipped = 0; // There's probably a better way to do this

    FinancialDataPoint? currentEmptyRunStart;

    for (int i = 0; i < points.length; i++) {
      var point = points[i];

      if (point.isEmpty) {
        currentEmptyRunStart ??= point;
        skipped += 1;
        continue;
      } else {
        if (currentEmptyRunStart != null) {
          skipped -= 1;
          DateTimeRange skippedRange = DateTimeRange(
            start: currentEmptyRunStart.dateRange.start,
            end: points[i - 1].dateRange.end,
          );
          data.add(createGroupData(
            FinancialDataPoint.empty(skippedRange),
            i - skipped - 1,
          ));
          currentEmptyRunStart = null;
          xTitles.add(formatDateLabel(skippedRange));
        }
      }

      data.add(createGroupData(
        point,
        i - skipped,
      ));

      xTitles.add(formatDateLabel(point.dateRange));

      if (point.spending > maxY) {
        maxY = point.spending;
      }

      if (point.income > maxY) {
        maxY = point.income;
      }
    }

    return BarChartCalculationData(data, xTitles, minY, maxY, data.isEmpty);
  }

  FlTitlesData _parseTitlesData(BarChartCalculationData data) {
    return FlTitlesData(
        topTitles: noTitlesWidget,
        rightTitles: noTitlesWidget,
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
                interval: calculateNiceInterval(data.minY, data.maxY, 5),
                showTitles: true,
                reservedSize: 55,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      "\$${formatYValue(value)}",
                    )))),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 65,
          getTitlesWidget: (value, meta) => SideTitleWidget(
              axisSide: meta.axisSide,
              space: 16,
              angle: -45 * 3.14 / 180,
              child: Text(data.xTitles[value.toInt()])),
        )));
  }

  @override
  Widget build(BuildContext context) {
    _filterProvider = context.watch<TransactionProvider>();

    return Card(
      margin: EdgeInsets.zero,
      color: getAdjustedColor(context, Theme.of(context).colorScheme.surface),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Spending vs income",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.left,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: AspectRatio(
            aspectRatio: 1,
            child: FutureBuilder<BarChartCalculationData>(
                future: _calculateData(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return errorInset(context, "No data");
                  }

                  var interval = calculateNiceInterval(
                      snapshot.data!.minY, snapshot.data!.maxY, 5);

                  return BarChart(BarChartData(
                      borderData: chartBorderData,
                      minY: snapshot.data?.minY,
                      maxY: adjustMaxYToNiceInterval(
                          snapshot.data!.maxY, interval),
                      gridData: FlGridData(
                        drawHorizontalLine: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval /
                            2, // Make the lines show up 2x more often than the titles
                        getDrawingHorizontalLine: (value) => FlLine(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                      ),
                      barGroups: snapshot.data!.groups,
                      titlesData: _parseTitlesData(snapshot.data!)));
                }),
          ),
        ),
      ]),
    );
  }
}
