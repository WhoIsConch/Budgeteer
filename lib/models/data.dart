import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class FinancialDataPoint {
  final DateTimeRange dateRange;
  final double spending;
  final double income;

  FinancialDataPoint(this.dateRange, this.spending, this.income);
}

class LineChartCalculationData {
  // Y titles are not necessary since they are in interval on the table
  final List<FlSpot> expenseSpots;
  final List<FlSpot> incomeSpots;
  final List<String> xTitles;
  final bool isEmpty;

  LineChartCalculationData(
      this.expenseSpots, this.incomeSpots, this.xTitles, this.isEmpty);
}
