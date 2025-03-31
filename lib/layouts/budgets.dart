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
  RelativeTimeRange selectedDateRange = RelativeTimeRange.today;
  bool chartIsLoading = true;

  Future<void> _prepareData() async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final List<Category> categories = [...provider.categories, Category(name: "Uncategorized")];

    List<PieChartSectionData> sectionData = [];
    List<MaterialColor> colors = [
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.blue,
      Colors.yellow,
      Colors.purple
    ];

    for (int i = 0; i < categories.length; i++) {
      Category category = categories[i];

      double total = await provider.getTotal(selectedDateRange.getRange(),
          category: category);

      if (total == 0) {
        continue;
      }

      sectionData.add(PieChartSectionData(
        value: total,
        radius: 32,
        title: category.name,
        color: colors[i],
      ));
    }

    setState(() {
      pieChartSectionData = sectionData;
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
        centerSpaceRadius: 100,
        sectionsSpace: 2,
        sections: pieChartSectionData));
  }

  DropdownMenu getDateRangeDropdown() => DropdownMenu(
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
    Widget pieChart;

    if (chartIsLoading) {
      pieChart = Center(
          child: SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator()));
    } else if (pieChartSectionData!.isEmpty) {
      pieChart = const Center(
          child: Text("Nothing to show.", style: TextStyle(fontSize: 24)));
    } else {
      pieChart = getPieChart();
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          getDateRangeDropdown(),
          SizedBox(child: AspectRatio(aspectRatio: 1.0, child: pieChart)),
        ]);
  }
}
