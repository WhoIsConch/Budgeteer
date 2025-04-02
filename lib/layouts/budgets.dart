import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/tools/api.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/enums.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CategoryPieChart();
  }
}

class CategoryPieChart extends StatefulWidget {
  const CategoryPieChart({super.key});

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  List<PieChartSectionData>? pieChartSectionData;
  List<ChartKeyItem>? chartKeyItems;
  RelativeTimeRange selectedDateRange = RelativeTimeRange.today;
  bool chartIsLoading = true;
  double totalSpent = 0;

  Future<void> _prepareData() async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final List<Category> categories = [
      Category(name: ""),
      ...provider.categories,
    ];
    totalSpent = 0;

    List<PieChartSectionData> sectionData = [];
    List<ChartKeyItem> keyItems = [];

    List<MaterialColor> colors = [
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.blue,
      Colors.yellow,
      Colors.purple,
      Colors.cyan,
      Colors.lightGreen,
    ];

    List<double> totals = [];
    double otherSectionTotal = 0;
    double overallTotal = 0;

    for (int i = 0; i < categories.length; i++) {
      double total = await provider.getTotal(selectedDateRange.getRange(),
          category: categories[i]);

      if (total == 0) {
        totals.add(0); // Add a zero to keep indexes aligned
        continue;
      }

      totals.add(total);

      overallTotal += total.abs();
      totalSpent -= total;
    }

    for (int i = 0; i < categories.length; i++) {
      if (totals[i] == 0) continue;

      double total = totals[i];
      double percentage = (total.abs() / overallTotal) * 100;

      if (percentage < 2) {
        otherSectionTotal += total;
        continue;
      }

      sectionData.add(PieChartSectionData(
        value: total.abs(),
        radius: 32,
        showTitle: false,
        color: colors[i],
      ));

      // This sorts the data to ensure any income stays on top to
      // organize the legend
      if (total > 0) {
        keyItems.insert(
            0,
            ChartKeyItem(
                color: colors[i],
                name: categories[i].name.isNotEmpty
                    ? categories[i].name
                    : "Uncategorized",
                icon: Icons.add_circle));
      } else {
        keyItems.add(ChartKeyItem(
            color: colors[i],
            name: categories[i].name.isNotEmpty
                ? categories[i].name
                : "Uncategorized",
            icon: Icons.remove_circle));
      }
    }

    if (otherSectionTotal != 0 &&
        (otherSectionTotal.abs() / overallTotal) * 100 >= 1) {
      sectionData.add(PieChartSectionData(
        value: otherSectionTotal,
        radius: 32,
        showTitle: false,
        color: Colors.grey,
      ));

      keyItems.add(ChartKeyItem(color: Colors.grey, name: "Other"));
    }

    setState(() {
      pieChartSectionData = sectionData;
      chartKeyItems = keyItems;
      chartIsLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    _prepareData();
  }

  PieChart getPieChart() {
    return PieChart(PieChartData(
        centerSpaceRadius: 56,
        sectionsSpace: 2,
        sections: pieChartSectionData));
  }

  DropdownMenu getDateRangeDropdown() => DropdownMenu(
        expandedInsets: EdgeInsets.zero,
        initialSelection: selectedDateRange,
        onSelected: (value) {
          selectedDateRange = value;
          _prepareData();
        },
        dropdownMenuEntries: RelativeTimeRange.values
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
    Widget pieChartArea;

    if (chartIsLoading) {
      pieChartArea = const Center(
          child: SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator()));
    } else if (pieChartSectionData!.isEmpty) {
      pieChartArea = const Center(
          child: Text("Nothing to show.", style: TextStyle(fontSize: 24)));
    } else {
      pieChartArea = Row(
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
                  child: AutoSizeText(
                    chartIsLoading
                        ? ""
                        : "\$${totalSpent.round().toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 48),
                    maxLines: 1,
                  ),
                )),
              ),
              AspectRatio(aspectRatio: 1.0, child: getPieChart())
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Column(
                spacing: 4,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: chartKeyItems!,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      // Contains the pie chart and all of its associated data
      children: [
        getDateRangeDropdown(), // Decide which time period to visit
        const SizedBox(height: 16),
        pieChartArea
      ],
    );
  }
}

class ChartKeyItem extends StatelessWidget {
  const ChartKeyItem(
      {super.key, required this.color, required this.name, this.icon});

  final MaterialColor color;
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
            style: TextStyle(fontSize: 18),
            maxLines: 1,
            minFontSize: 10,
          ),
        ),
        const SizedBox(width: 6),
        icon == null
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: color,
                ),
                child: SizedBox(height: 16, width: 16),
              )
            : Icon(icon, color: color),
      ],
    );
  }
}
