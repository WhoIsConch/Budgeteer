import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/components/hybrid_button.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/validators.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/enums.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  List<PieChartSectionData>? pieChartSectionData;
  List<ChartKeyItem>? chartKeyItems;
  RelativeTimeRange selectedDateRange = RelativeTimeRange.today;
  bool chartIsLoading = true;
  double cashFlow = 0;
  int typeIndex = 0;
  List<TransactionType?> transactionTypes = [null, ...TransactionType.values];

  TransactionType? get currentTransactionType =>
      transactionTypes[typeIndex % transactionTypes.length];

  Future<void> _prepareData() async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final List<Category> categories = [
      Category(name: ""),
      ...provider.categories,
    ];
    cashFlow = 0;

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

    for (int i = 0; i < categories.length; i++) {
      double total =
          switch (transactionTypes[typeIndex % transactionTypes.length]) {
        null => (await provider.getAmountSpent(selectedDateRange.getRange(),
                    category: categories[i]))
                .abs() +
            (await provider.getAmountEarned(selectedDateRange.getRange(),
                    category: categories[i]))
                .abs(),
        TransactionType.expense => await provider.getAmountSpent(
            selectedDateRange.getRange(),
            category: categories[i]),
        TransactionType.income => await provider.getAmountEarned(
            selectedDateRange.getRange(),
            category: categories[i]),
      };

      if (total == 0) {
        totals.add(0); // Add a zero to keep indexes aligned
        continue;
      }

      totals.add(total);

      cashFlow += total.abs();
    }

    for (int i = 0; i < categories.length; i++) {
      if (totals[i] == 0) continue;

      double total = totals[i];
      double percentage = (total.abs() / cashFlow) * 100;

      if (percentage < 2) {
        otherSectionTotal += total.abs();
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
                    : "Uncategorized"));
      } else {
        keyItems.add(ChartKeyItem(
            color: colors[i],
            name: categories[i].name.isNotEmpty
                ? categories[i].name
                : "Uncategorized"));
      }
    }

    if (otherSectionTotal != 0) {
      if ((otherSectionTotal.abs() / cashFlow) * 100 >= 1) {
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
    List<Icon> typesIcons = [
      const Icon(Icons.all_inclusive),
      const Icon(Icons.remove),
      const Icon(Icons.add),
    ];

    if (chartIsLoading) {
      pieChartArea = const Expanded(
        child: Center(
            child: SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator())),
      );
    } else if (pieChartSectionData!.isEmpty) {
      pieChartArea = const Expanded(
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AutoSizeText(
                        "\$${formatAmount(cashFlow.round())}",
                        style: const TextStyle(fontSize: 48),
                        maxLines: 1,
                      ),
                    ],
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
        Row(
          spacing: 8.0,
          children: [
            Expanded(child: getDateRangeDropdown()),
            HybridButton(
                isEnabled: typeIndex % typesIcons.length != 0,
                buttonType: HybridButtonType.toggle,
                onTap: () {
                  setState(() {
                    typeIndex += 1;
                  });
                  _prepareData();
                },
                icon: typesIcons[typeIndex % typesIcons.length])
          ],
        ),
        // Decide which time period to visit
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

class CategoryBarChart extends StatefulWidget {
  const CategoryBarChart({super.key});

  @override
  State<CategoryBarChart> createState() => _CategoryBarChartState();
}

class _CategoryBarChartState extends State<CategoryBarChart> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
