import 'package:budget/tools/api.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/enums.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  Widget getPieChart() {
    return PieChart(PieChartData(centerSpaceRadius: 0.0, sections: [
      PieChartSectionData(
          radius: 100.0,
          value: 40,
          color: Colors.red,
          titleStyle: TextStyle(fontSize: 32)),
      PieChartSectionData(
        radius: 75.0,
        value: 40,
        color: Colors.blue,
      ),
      PieChartSectionData(
        radius: 50.0,
        value: 40,
        color: Colors.green,
      )
    ]));
  }

  Widget getScatterChart() {
    List<ScatterSpot> scatterSpots = [];

    return Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
      List<Transaction> transactions = transactionProvider.transactions;
      List<String> xTitles = [];
      List<String> yTitles = [];

      for (Transaction transaction in transactions) {
        scatterSpots.add(ScatterSpot(
            transaction.date.millisecondsSinceEpoch.toDouble(),
            transaction.amount,
            dotPainter: FlDotCirclePainter(
              color: transaction.type == TransactionType.income
                  ? Colors.blue
                  : Colors.red,
              radius: 10,
            )));

        xTitles.add(transaction.formatDate());
        yTitles.add(transaction.formatAmount());
      }

      return ScatterChart(ScatterChartData(scatterSpots: scatterSpots));
    });
  }

  @override
  Widget build(BuildContext context) {
    return getScatterChart();
  }
}
