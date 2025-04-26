import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/views/components/category_dropdown.dart';
import 'package:budget/views/components/hybrid_button.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/utils/validators.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  // In this case, filters should include a DateRangeFilter, CategoryFilter,
  // and/or TypeFilter
  late TransactionProvider filterProvider;
  late AppDatabase dbProvider;
  late TransactionDao daoProvider;

  int typeIndex = 0;
  List<Transaction> transactions = [];

  final List<Icon> typesIcons = [
    const Icon(Icons.all_inclusive),
    const Icon(Icons.remove),
    const Icon(Icons.add),
  ];

  final List<TransactionType?> types = [null, ...TransactionType.values];

  List<Category> get selectedCategories =>
      filterProvider.getFilterValue<List<Category>>() ?? [];

  // TODO: Make sure RelativeDateRange is never passed to the filters in api.dart
  RelativeDateRange get dateRange =>
      filterProvider.getFilterValue<RelativeDateRange>() ??
      RelativeDateRange.today;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    filterProvider = context.watch<TransactionProvider>();
    dbProvider = context.read<AppDatabase>();
    daoProvider = context.read<TransactionDao>();
  }

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(spacing: 8.0, children: [
          Expanded(child: getDateRangeDropdown()),
          HybridButton(
              isEnabled: typeIndex % typesIcons.length != 0,
              icon: typesIcons[typeIndex % typesIcons.length],
              buttonType: HybridButtonType.toggle,
              onTap: () {
                typeIndex += 1;
                TransactionType? type = types[typeIndex % types.length];
                if (type == null) {
                  filterProvider.removeFilter<TransactionType>();
                } else {
                  filterProvider.updateFilter<TransactionType>(
                      TransactionFilter<TransactionType>(type));
                }
              })
        ]),
        const SizedBox(height: 16),
        CategoryPieChart(
          categoriesStream: dbProvider.watchCategories(),
        ),
        const SizedBox(height: 16),
        StreamBuilder(
            stream: dbProvider.watchCategories(),
            builder: (context, snapshot) {
              return CategoryDropdown(
                  categories: snapshot.data ?? [],
                  showExpanded: false,
                  onChanged: (Category? category) => setState(() {
                        if (category?.id == null || category!.id.isEmpty) {
                          filterProvider.removeFilter<List<Category>>();
                          return;
                        }

                        filterProvider.updateFilter<List<Category>>(
                            TransactionFilter<List<Category>>([category]));
                      }),
                  selectedCategory: selectedCategories.firstOrNull);
            }),
        const Spacer(),
        StreamBuilder<List<Transaction>>(
          stream: daoProvider.watchTransactionsPage(
              filters: filterProvider.filters, sort: filterProvider.sort),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Text("Error: ${snapshot.error}");
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text("No transactions found.");
            } else {
              return CategoryBarChart(
                transactions: snapshot.data!,
                dateRange: dateRange,
              );
            }
          },
        ),
      ],
    );
  }
}

class CategoryBarChart extends StatelessWidget {
  final List<Transaction> transactions;
  final RelativeDateRange dateRange;

  const CategoryBarChart(
      {super.key, required this.dateRange, required this.transactions});

  BarTouchData barTouchData(BuildContext context) => BarTouchData(
      enabled: false,
      touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => Colors.transparent,
          tooltipPadding: EdgeInsets.zero,
          tooltipMargin: 8,
          getTooltipItem: (
            BarChartGroupData group,
            int groupIndex,
            BarChartRodData rod,
            int rodIndex,
          ) =>
              BarTooltipItem(
                  "\$${formatAmount(rod.toY, round: true)}",
                  TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontSize: 24,
                  ))));

  FlTitlesData get titlesData => FlTitlesData(
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: getTitles,
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );

  SideTitleWidget getTitles(double value, TitleMeta meta) {
    String text = switch (dateRange) {
      RelativeDateRange.today || RelativeDateRange.yesterday => switch (value) {
          0 => "Spent",
          1 => "Earned",
          _ => "!!!"
        },
      RelativeDateRange.thisWeek => switch (value) {
          1 => "Mn",
          2 => "Tu",
          3 => "Wd",
          4 => "Th",
          5 => "Fr",
          6 => "St",
          7 => "Sn",
          _ => "!!"
        },
      RelativeDateRange.thisMonth => value.toStringAsFixed(0),
      RelativeDateRange.thisYear => switch (value) {
          1 => "Jan",
          2 => "Feb",
          3 => "Mar",
          4 => "Apr",
          5 => "May",
          6 => "Jun",
          7 => "Jul",
          8 => "Aug",
          9 => "Sep",
          10 => "Oct",
          11 => "Nov",
          12 => "Dec",
          _ => "!!!"
        }
    };

    return SideTitleWidget(
      axisSide: AxisSide.bottom,
      child: Text(text),
    );
  }

  BarChart _buildBarChart(BuildContext context) {
    Map<int, double> valuePairs = {};

    // Used reversed because the resultant is usually in descending order
    // which is not preferred

    for (Transaction e in transactions.reversed) {
      int xValue = switch (dateRange) {
        RelativeDateRange.today ||
        RelativeDateRange.yesterday =>
          e.type == TransactionType.expense ? 0 : 1,
        RelativeDateRange.thisWeek => e.date.weekday,
        RelativeDateRange.thisMonth => e.date.day,
        RelativeDateRange.thisYear => e.date.month,
      };

      // Either adds a new key or updates the existing key to ensure
      // the data is represented in the table in the same groups
      valuePairs.update(xValue, (value) => value + e.amount,
          ifAbsent: () => e.amount);
    }

    List<BarChartGroupData> bars = [];
    valuePairs.forEach(
      (key, value) => bars.add(BarChartGroupData(
        barsSpace: 10,
        showingTooltipIndicators: [0],
        x: key,
        barRods: [
          BarChartRodData(
              width: 16,
              color: Theme.of(context).colorScheme.primary,
              toY: value)
        ],
      )),
    );

    return BarChart(BarChartData(
        maxY: valuePairs.values.reduce(
          (value, element) => value > element ? value : element,
        ),
        barTouchData: barTouchData(context),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: bars,
        alignment: BarChartAlignment.spaceAround,
        titlesData: titlesData));
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(aspectRatio: 1.6, child: _buildBarChart(context));
  }
}

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

class CategoryPieChart extends StatefulWidget {
  final Stream<List<Category>> categoriesStream;

  const CategoryPieChart({super.key, required this.categoriesStream});

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  late final TransactionDao _daoProvider;

  Future<ChartCalculationResult> _calculateChartData({
    required List<Category?> categories,
    required List<TransactionFilter> filters,
  }) async {
    double absTotal = 0;
    List<PieChartSectionData> sectionData = [];
    List<ChartKeyItem> keyItems = [];
    List<double> totals = [];
    double otherSectionTotal = 0;

    TransactionType? typeFilter = filters
        .firstWhereOrNull((e) => e.value.runtimeType == TransactionType)
        ?.value;
    RelativeDateRange? dateFilter = filters
        .firstWhereOrNull((e) => e.value.runtimeType == RelativeDateRange)
        ?.value;

    List<Future<double>> futures = [];
    for (final category in categories) {
      futures.add(_daoProvider.getTotalAmount(
          nullCategory: category == null,
          category: category,
          type: typeFilter,
          dateRange: dateFilter?.getRange(fullRange: true)));
    }
    totals = await Future.wait(futures);

    for (final total in totals) {
      absTotal += total.abs();
    }

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
          radius: 32,
          showTitle: false,
          color: color,
        ));

        final keyItem = ChartKeyItem(color: color, name: name);
        if (total > 0) {
          keyItems.insert(0, keyItem);
        } else {
          keyItems.add(keyItem);
        }
      }
    }

    if (otherSectionTotal != 0 && (otherSectionTotal / absTotal) * 100 >= 1) {
      sectionData.add(PieChartSectionData(
        value: otherSectionTotal,
        radius: 32,
        showTitle: false,
        color: Colors.grey,
      ));
      keyItems.add(const ChartKeyItem(color: Colors.grey, name: "Other"));
    }

    return ChartCalculationResult(
      sectionData: sectionData,
      keyItems: keyItems,
      totalAmount: absTotal,
      isEmpty: sectionData.isEmpty,
    );
  }

  @override
  void initState() {
    super.initState();

    _daoProvider = context.read<TransactionDao>();
  }

  @override
  Widget build(BuildContext context) {
    final filters = context.watch<TransactionProvider>().filters;

    return StreamBuilder<List<Category>>(
      stream: widget.categoriesStream,
      builder: (context, categorySnapshot) {
        if (categorySnapshot.connectionState == ConnectionState.waiting) {
          return const Expanded(
              child: Center(child: CircularProgressIndicator()));
        }
        if (categorySnapshot.hasError) {
          return Expanded(
              child: Center(
                  child: Text(
                      'Error loading categories: ${categorySnapshot.error}')));
        }
        if (!categorySnapshot.hasData || categorySnapshot.data!.isEmpty) {
          return const Expanded(
              child: Center(child: Text("No categories available.")));
        }

        final availableCategories = categorySnapshot.data!;
        final categoriesWithNull = [...availableCategories, null];

        return FutureBuilder<ChartCalculationResult>(
          future: _calculateChartData(
            categories: categoriesWithNull,
            filters: filters,
          ),
          key: ValueKey(Object.hash(categoriesWithNull, filters)),
          builder: (context, calculationSnapshot) {
            if (calculationSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Expanded(
                  child: Center(child: CircularProgressIndicator()));
            }
            if (calculationSnapshot.hasError) {
              print(
                  "Error calculating chart data: ${calculationSnapshot.error}");
              print("Stack trace: ${calculationSnapshot.stackTrace}");
              return Expanded(
                  child: Center(
                      child: Text(
                          'Error calculating chart: ${calculationSnapshot.error}')));
            }
            if (!calculationSnapshot.hasData) {
              return const Expanded(
                  child:
                      Center(child: Text("Could not calculate chart data.")));
            }

            final result = calculationSnapshot.data!;

            if (result.isEmpty) {
              return const Expanded(
                child: SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Nothing to show.",
                          style: TextStyle(fontSize: 24),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          "Try changing the date range or adding some transactions.",
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        )
                      ],
                    )),
              );
            } else {
              final pieChartData = PieChartData(
                centerSpaceRadius: 56,
                sectionsSpace: 2,
                sections: result.sectionData,
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 180,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 112,
                        height: 112,
                        child: Center(
                            child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AutoSizeText(
                                "\$${formatAmount(result.totalAmount.round())}",
                                style: const TextStyle(fontSize: 48),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        )),
                      ),
                      AspectRatio(
                          aspectRatio: 1.0, child: PieChart(pieChartData))
                    ]),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 180,
                      child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ListView(children: result.keyItems)),
                    ),
                  ),
                ],
              );
            }
          },
        );
      },
    );
  }
}

class ChartKeyItem extends StatelessWidget {
  const ChartKeyItem(
      {super.key, required this.color, required this.name, this.icon});

  final Color color;
  final String name;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: AutoSizeText(
            name,
            softWrap: true,
            style: const TextStyle(fontSize: 18),
            maxLines: 1,
            minFontSize: 10,
          ),
        ),
        const SizedBox(width: 6),
        icon == null
            ? Padding(
                padding: const EdgeInsets.all(2.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(height: 20, width: 20),
                ),
              )
            : Icon(icon, color: color),
      ],
    );
  }
}
