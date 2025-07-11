import 'dart:math';

import 'package:budget/appui/components/pie_chart.dart';
import 'package:budget/appui/components/status.dart';
import 'package:budget/appui/components/top_containers.dart';
import 'package:budget/models/data.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/services/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/enums.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:collection/collection.dart';
import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final TextEditingController _rangeController = TextEditingController();

  void pickDateRange(
    BuildContext context, {
    DateTimeRange? initialRange,
  }) async {
    final provider = context.read<TransactionProvider>();

    DateTimeRange? newRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    );

    if (newRange == null) return;

    provider.updateFilter(DateRangeFilter(newRange));
  }

  DropdownMenu getDateRangeDropdown(BuildContext context) {
    final dateFilter =
        context.read<TransactionProvider>().getFilter<DateRangeFilter>();

    List<DropdownMenuEntry<DateTimeRange>> entries =
        RelativeDateRange.values
            .map(
              (e) => DropdownMenuEntry<DateTimeRange>(
                value: e.getRange(),
                label: e.name,
              ),
            )
            .toList();

    RelativeDateRange? selectedRelRange = RelativeDateRange.values
        .firstWhereOrNull(
          (element) =>
              element.getRange() ==
              (dateFilter?.dateRange ?? RelativeDateRange.today.getRange()),
        );

    if (selectedRelRange != null) {
      _rangeController.text = selectedRelRange.name;
    } else {
      // This means a custom range
      _rangeController.text = dateFilter!.dateRange.asString();
    }

    return DropdownMenu<DateTimeRange>(
      controller: _rangeController,
      expandedInsets: EdgeInsets.zero,
      initialSelection: dateFilter?.dateRange,
      onSelected: (range) async {
        if (range == null) {
          pickDateRange(context, initialRange: dateFilter?.dateRange);
        } else {
          context.read<TransactionProvider>().updateFilter(
            DateRangeFilter(range),
          );
        }
      },
      dropdownMenuEntries: entries,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TransactionProvider>(
      create: (context) {
        final filterProvider = TransactionProvider();

        filterProvider.updateFilter(
          DateRangeFilter(RelativeDateRange.thisMonth.getRange()),
        );

        return filterProvider; // Ensure the buttons update
      },
      builder: (context, _) {
        DateRangeFilter? initialRange =
            context.watch<TransactionProvider>().getFilter<DateRangeFilter>();

        return SingleChildScrollView(
          clipBehavior: Clip.none,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: getDateRangeDropdown(context)),
                  const SizedBox(width: 4),
                  IconButton(
                    iconSize: 32,
                    icon: const Icon(Icons.date_range),
                    onPressed:
                        () => pickDateRange(
                          context,
                          initialRange: initialRange?.dateRange,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8.0), // Bottom padding
              const PieChartCard(),
              const SizedBox(height: 8.0),
              // const LineChartCard(),
              const SpendingBarChart(),
              const SizedBox(height: 8.0),
              const TopContainers(),
              const SizedBox(height: 60), // To give the FAB somewhere to go
            ],
          ),
        );
      },
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
      _filtersProvider.getFilter<DateRangeFilter>()?.dateRange ??
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
    final AppDatabase db = context.read<AppDatabase>();

    AggregationLevel aggregationLevel = switch (daysDifference) {
      <= 90 => AggregationLevel.daily,
      <= 365 => AggregationLevel.weekly,
      _ => AggregationLevel.monthly,
    };

    final List<FinancialDataPoint> points = await db.transactionDao
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
          final String firstDate = DateFormat.Md().format(
            point.dateRange.start,
          );
          final String lastDate = DateFormat.Md().format(point.dateRange.end);

          xTitles.add('$firstDate–$lastDate');
          break;
        case _:
          xTitles.add(DateFormat.MMM().format(point.dateRange.start));
          break;
      }
    }

    return (
      expenseSpots: expenseSpots,
      incomeSpots: incomeSpots,
      xTitles: xTitles,
      isEmpty: xTitles.isEmpty,
    );
  }

  LineChartBarData _getChartBarData(List<FlSpot> spots, Color color) =>
      LineChartBarData(
        isStrokeCapRound: true,
        isCurved: true,
        curveSmoothness: 0.15,
        barWidth: 4,
        color: color.harmonizeWith(Theme.of(context).colorScheme.primary),
        spots: spots,
      );

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

    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          // Fucking useless and unreasonably verbose way to describe titles on a chart
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _calculateYAxisInterval(minAmount, maxAmount),
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  child: Text('\$${value.toInt()}'),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            // X axis are stuck here since they use line chart calculation data
            sideTitles: SideTitles(
              reservedSize: 36,
              showTitles: true,
              getTitlesWidget:
                  (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Transform.rotate(
                      angle: -45 * 3.14 / 180,
                      child: Text(data.xTitles[value.toInt()]),
                    ),
                  ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles()),
          rightTitles: const AxisTitles(sideTitles: SideTitles()),
        ),
        borderData: FlBorderData(show: false),
        // gridData: const FlGridData(show: false),
        lineBarsData: [
          _getChartBarData(data.expenseSpots, Colors.red),
          _getChartBarData(data.incomeSpots, Colors.green),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _filtersProvider = context.watch<TransactionProvider>();

    return AspectRatio(
      aspectRatio: 3 / 2,
      child: Card(
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: FutureBuilder(
            future: _calculateData(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return ErrorInset.noData;
              } else if ((snapshot.data!.expenseSpots.length +
                      snapshot.data!.incomeSpots.length) <
                  3) {
                // If there aren't enough spots the table will look pointless
                return ErrorInset('Insufficient data');
              } else if (snapshot.hasError) {
                return ErrorInset('Something went wrong');
              } else {
                return _getLineChart(snapshot.data!);
              }
            },
          ),
        ),
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
      _filterProvider.getFilter<DateRangeFilter>()?.dateRange ??
      RelativeDateRange.today.getRange();

  AxisTitles get noTitlesWidget =>
      const AxisTitles(sideTitles: SideTitles(showTitles: false));

  FlBorderData get chartBorderData {
    var borderSide = BorderSide(
      color: Theme.of(context).colorScheme.outlineVariant,
      width: 2.0,
    );

    return FlBorderData(
      show: true,
      border: Border(bottom: borderSide, top: borderSide),
    );
  }

  BarChartGroupData createGroupData(FinancialDataPoint point, int x) =>
      BarChartGroupData(
        barsSpace: 4,
        x: x,
        barRods: [
          BarChartRodData(
            width: 8,
            toY: point.income,
            color: Colors.green.harmonizeWith(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          BarChartRodData(
            width: 8,
            toY: point.spending,
            color: Colors.red.harmonizeWith(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );

  Future<BarChartCalculationData> _calculateData() async {
    final int daysDifference = dateRange.duration.inDays;
    final AppDatabase db = context.read<AppDatabase>();

    AggregationLevel aggregationLevel = switch (daysDifference) {
      <= 90 => AggregationLevel.daily,
      <= 365 => AggregationLevel.weekly,
      _ => AggregationLevel.monthly,
    };

    List<FinancialDataPoint> points = await db.transactionDao
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
          data.add(
            createGroupData(
              FinancialDataPoint.empty(skippedRange),
              i - skipped - 1,
            ),
          );
          currentEmptyRunStart = null;
          xTitles.add(formatDateLabel(skippedRange));
        }
      }

      data.add(createGroupData(point, i - skipped));

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
          reservedSize: 50,
          getTitlesWidget:
              (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text('\$${formatYValue(value)}'),
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
              ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 65,
          getTitlesWidget:
              (value, meta) => SideTitleWidget(
                meta: meta,
                space: 16,
                angle: -45 * 3.14 / 180,
                child: Text(data.xTitles[value.toInt()]),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _filterProvider = context.watch<TransactionProvider>();

    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Spending vs income',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.left,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 300,
              child: FutureBuilder<BarChartCalculationData>(
                future: _calculateData(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return ErrorInset.noData;
                  }

                  var interval = calculateNiceInterval(
                    snapshot.data!.minY,
                    snapshot.data!.maxY,
                    5,
                  );
                  double chartWidth = max(
                    MediaQuery.of(context).size.width - 32,
                    snapshot.data!.groups.length * 24,
                  );

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      child: BarChart(
                        // transformationConfig: FlTransformationConfig(
                        //   scaleAxis: FlScaleAxis.horizontal,
                        // ),
                        BarChartData(
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem:
                                  (
                                    group,
                                    groupIndex,
                                    rod,
                                    rodIndex,
                                  ) => BarTooltipItem(
                                    '\$${formatAmount(rod.toY, exact: true)}',
                                    TextStyle(
                                      color: rod.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            ),
                          ),
                          borderData: chartBorderData,
                          minY: snapshot.data?.minY,
                          maxY: adjustMaxYToNiceInterval(
                            snapshot.data!.maxY,
                            interval,
                          ),
                          gridData: FlGridData(
                            drawHorizontalLine: true,
                            drawVerticalLine: false,
                            horizontalInterval:
                                interval /
                                2, // Make the lines show up 2x more often than the titles
                            getDrawingHorizontalLine:
                                (value) => FlLine(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                ),
                          ),
                          barGroups: snapshot.data!.groups,
                          titlesData: _parseTitlesData(snapshot.data!),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
