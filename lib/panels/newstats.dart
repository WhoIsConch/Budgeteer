import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/components/hybrid_button.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/filters.dart';
import 'package:budget/tools/validators.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  // In this case, filters should include a DateRangeFilter, CategoryFilter,
  // and/or TypeFilter
  List<TransactionFilter> filters = [];
  int typeIndex = 0;
  List<Transaction> transactions = [];

  final List<Icon> typesIcons = [
    const Icon(Icons.all_inclusive),
    const Icon(Icons.remove),
    const Icon(Icons.add),
  ];

  final List<TransactionType?> types = [null, ...TransactionType.values];

  RelativeDateRange dateRange() {
    RelativeDateRange? value = getFilterValue<RelativeDateRange>(filters);

    if (value == null) {
      updateFilter(filters,
          const TransactionFilter<RelativeDateRange>(RelativeDateRange.today));

      return RelativeDateRange.today;
    }

    return value;
  }

  DropdownMenu getDateRangeDropdown() => DropdownMenu(
        expandedInsets: EdgeInsets.zero,
        initialSelection: dateRange(),
        onSelected: (value) => setState(() =>
            updateFilter(filters, TransactionFilter<RelativeDateRange>(value))),
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
    return Consumer<TransactionProvider>(
      builder:
          (BuildContext context, TransactionProvider provider, Widget? child) =>
              Column(
        children: [
          Row(spacing: 8.0, children: [
            Expanded(child: getDateRangeDropdown()),
            HybridButton(
                isEnabled: typeIndex % typesIcons.length != 0,
                icon: typesIcons[typeIndex % typesIcons.length],
                buttonType: HybridButtonType.toggle,
                onTap: () {
                  setState(() {
                    typeIndex += 1;
                    TransactionType? type = types[typeIndex % types.length];
                    if (type == null) {
                      setState(() => removeFilter<TransactionType>(filters));
                    } else {
                      setState(() => updateFilter(
                          filters, TransactionFilter<TransactionType>(type)));
                    }
                  });
                })
          ]),
          const SizedBox(height: 16),
          CategoryPieChart(
            availableCategories: provider.categories,
            filters: filters,
          ),
          const SizedBox(height: 32),
          StreamBuilder<List<Transaction>>(
            stream: provider.getQueryStream(provider.getQuery(
                filters: filters
                  ..add(TransactionFilter<RelativeDateRange>(dateRange())))),
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
                  dateRange: dateRange(),
                );
              }
            },
          ),
        ],
      ),
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

class CategoryPieChart extends StatefulWidget {
  final List<Category> availableCategories;
  final List<TransactionFilter> filters;

  const CategoryPieChart(
      {super.key, required this.availableCategories, required this.filters});

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  List<PieChartSectionData>? pieChartSectionData;
  List<ChartKeyItem>? chartKeyItems;
  bool isLoading = true;
  double totalAmount = 0;

  PieChart get pieChart => PieChart(PieChartData(
      centerSpaceRadius: 56, sectionsSpace: 2, sections: pieChartSectionData));

  Future<void> _prepareData(BuildContext context) async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final List<Category> categories = [
      Category(name: ""),
      ...provider.categories,
    ];
    double absTotal = 0;

    List<PieChartSectionData> sectionData = [];
    List<ChartKeyItem> keyItems = [];

    List<double> totals = [];
    double otherSectionTotal = 0;

    for (int i = 0; i < categories.length; i++) {
      TransactionType? type = getFilterValue<TransactionType>(widget.filters);

      double total = switch (type) {
        null => (await provider.getTotalAmount(category: categories[i])),
        _ => await provider.getTotalAmount(type: type, category: categories[i])
      };

      if (total == 0) {
        totals.add(0); // Add a zero to keep indexes aligned
        continue;
      }

      totals.add(total);

      absTotal += total.abs();
    }

    for (int i = 0; i < categories.length; i++) {
      if (totals[i] == 0) continue;

      double total = totals[i];
      double percentage = (total.abs() / absTotal) * 100;

      if (percentage < 2) {
        otherSectionTotal += total.abs();
        continue;
      }

      sectionData.add(PieChartSectionData(
        value: total.abs(),
        radius: 32,
        showTitle: false,
        color: categories[i].color ?? Colors.white,
      ));

      // This sorts the data to ensure any income stays on top to
      // organize the legend
      if (total > 0) {
        keyItems.insert(
            0,
            ChartKeyItem(
                color: categories[i].color ?? Colors.white,
                name: categories[i].name.isNotEmpty
                    ? categories[i].name
                    : "Uncategorized"));
      } else {
        keyItems.add(ChartKeyItem(
            color: categories[i].color ?? Colors.white,
            name: categories[i].name.isNotEmpty
                ? categories[i].name
                : "Uncategorized"));
      }
    }

    if (otherSectionTotal != 0) {
      if ((otherSectionTotal.abs() / absTotal) * 100 >= 1) {
        sectionData.add(PieChartSectionData(
          value: otherSectionTotal,
          radius: 32,
          showTitle: false,
          color: Colors.grey,
        ));
      }

      keyItems.add(const ChartKeyItem(color: Colors.grey, name: "Other"));
    }

    setState(() {
      pieChartSectionData = sectionData;
      chartKeyItems = keyItems;
      isLoading = false;
      totalAmount = absTotal;
    });
  }

  @override
  void initState() {
    super.initState();

    _prepareData(context);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Expanded(
        child: Center(
            child: SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator())),
      );
    } else if (pieChartSectionData!.isEmpty) {
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
      return Row(
        // Contains the Pie Chart and the Legend
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            // Pie Chart and its total amount stack
            width: 180, // Same width as the pie chart
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
                        "\$${formatAmount(totalAmount.round())}",
                        style: const TextStyle(fontSize: 48),
                        maxLines: 1,
                      ),
                    ],
                  ),
                )),
              ),
              AspectRatio(aspectRatio: 1.0, child: pieChart)
            ]),
          ),
          Expanded(
            child: SizedBox(
              height: 180,
              child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: ListView(children: chartKeyItems!)),
            ),
          ),
        ],
      );
    }
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
