import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/appui/components/status.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PieChartSelectionData<T> {
  final T type;
  final int index;
  final String label;

  const PieChartSelectionData({
    required this.type,
    required this.index,
    required this.label,
  });

  static const netType = PieChartSelectionData<TransactionType?>(
    type: null,
    index: 0,
    label: 'Cash Flow',
  );
  static const expenseType = PieChartSelectionData<TransactionType?>(
    type: TransactionType.expense,
    index: 1,
    label: 'Expense',
  );
  static const incomeType = PieChartSelectionData<TransactionType?>(
    type: TransactionType.income,
    index: 2,
    label: 'Income',
  );

  static const categoryType = PieChartSelectionData(
    type: ContainerType.category,
    index: 0,
    label: 'Category',
  );
  static const accountType = PieChartSelectionData(
    type: ContainerType.account,
    index: 1,
    label: 'Account',
  );
  static const goalType = PieChartSelectionData(
    type: ContainerType.goal,
    index: 2,
    label: 'Goal',
  );

  static const typeList = [netType, expenseType, incomeType];
  static const containerList = [categoryType, accountType, goalType];

  @override
  int get hashCode => type.hashCode ^ index.hashCode ^ label.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PieChartSelectionData &&
            runtimeType == other.runtimeType &&
            type == other.type &&
            index == other.index &&
            label == other.label;
  }
}

class PieChartObject {
  final String name;
  final Color color;
  final double amount;

  const PieChartObject({
    required this.name,
    required this.color,
    required this.amount,
  });
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

class ChartKeyItem extends StatelessWidget {
  const ChartKeyItem({
    super.key,
    required this.color,
    required this.name,
    this.icon,
    required this.percent,
  });

  final Color color;
  final String name;
  final int percent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 18);

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
                  borderRadius: BorderRadius.circular(6),
                ),
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
        Text('$percent%', style: textStyle),
      ],
    );
  }
}

class VerticalTabButton extends StatelessWidget {
  final String text;
  final void Function() onPressed;
  final bool isSelected;

  const VerticalTabButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isSelected = false,
  });

  static const double height = 40.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // height: height,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor:
              isSelected ? Theme.of(context).colorScheme.surface : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
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

class _PieChartCardState extends State<PieChartCard> {
  // I couldn't think of a better name for these so they are
  // typeIndex for the type of transaction and containerIndex
  // for the containers a transaction belongs to
  // In this case, goals, categories, and accounts are containers
  PieChartSelectionData<TransactionType?> _selectedType =
      PieChartSelectionData.netType;
  PieChartSelectionData<ContainerType> _selectedContainer =
      PieChartSelectionData.categoryType;

  final chartCenterRadius = 60.0; // Don't let the text go beyond that radius

  List<Widget> _buildVerticalTabs<T>(
    List<PieChartSelectionData<T>> tabs,
    PieChartSelectionData<T> selectedObj,
    ValueChanged<PieChartSelectionData<T>> onTabSelected,
  ) => List.generate(tabs.length, (index) {
    final data = tabs.where((e) => e.index == index).single;

    return VerticalTabButton(
      text: data.label,
      isSelected: data == selectedObj,
      onPressed: () => onTabSelected(data),
    );
  });

  Future<ChartCalculationResult> _calculateChartData({
    required List<PieChartObject?> objects,
  }) async {
    double absTotal = 0;
    List<PieChartSectionData> sectionData = [];
    List<ChartKeyItem> keyItems = [];
    double otherSectionTotal = 0;

    final totals = objects.map((e) => e?.amount ?? 0).toList();

    absTotal = totals.sum.abs();

    if (absTotal == 0) {
      return ChartCalculationResult(
        sectionData: [],
        keyItems: [],
        totalAmount: 0,
        isEmpty: true,
      );
    }

    for (int i = 0; i < objects.length; i++) {
      final object = objects[i];
      final total = totals[i];

      if (total == 0) continue;

      double percentage = (total.abs() / absTotal) * 100;

      final color = object?.color ?? Colors.grey[400]!;
      final name = object?.name ?? 'Uncategorized';

      if (percentage < 2) {
        otherSectionTotal += total.abs();
      } else {
        sectionData.add(
          PieChartSectionData(
            value: total.abs(),
            radius: 36,
            showTitle: false,
            color: color,
          ),
        );

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
        sectionData.add(
          PieChartSectionData(
            value: otherSectionTotal,
            radius: 36,
            showTitle: false,
            color: Colors.grey,
          ),
        );
        keyItems.add(
          ChartKeyItem(
            color: Colors.grey,
            name: 'Other',
            percent: percentage.round(),
          ),
        );
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
    String formattedAmount = formatAmount(
      data.totalAmount.abs(),
      round: true,
      exact: true,
    );

    String amountString;

    if (amountIsNegative) {
      amountString = '-\$$formattedAmount';
    } else {
      amountString = '\$$formattedAmount';
    }

    return SizedBox(
      width: 200,
      height: 200,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width:
                    (chartCenterRadius - 12) *
                    2, // To give it some padding and account for the fact that this is a radius and the text fits within the diameter
                child: AutoSizeText(
                  textAlign: TextAlign.center,
                  amountString,
                  style: Theme.of(context).textTheme.headlineLarge,
                  maxLines: 1,
                ),
              ),
            ),
            PieChart(
              PieChartData(
                centerSpaceRadius: chartCenterRadius,
                sections: data.sectionData,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<List<PieChartObject?>> _getContainerStream() {
    final provider = context.watch<TransactionProvider>();

    final db = context.read<AppDatabase>();
    final bool net = _selectedType.type != null;

    // TODO: Fix the way the total amount and container streams are joined...
    // probably make this less repetitive
    switch (_selectedContainer.type) {
      case ContainerType.account:
        return db.accountDao
            .watchAccounts(filters: provider.filters, net: net)
            .asyncMap((List<AccountWithTotal> accounts) async {
              final noAccounts =
                  await db.transactionDao
                      .watchTotalAmount(
                        filters: provider.filters,
                        net: net,
                        nullAccount: true,
                      )
                      .first;

              final List<PieChartObject> objects =
                  accounts
                      .map(
                        (account) => PieChartObject(
                          name: account.account.name,
                          color: account.account.color,
                          amount: account.total,
                        ),
                      )
                      .toList();
              return [
                ...objects,
                PieChartObject(
                  name: 'No account',
                  color: Colors.grey,
                  amount: noAccounts ?? 0,
                ),
              ];
            });
      case ContainerType.category:
        return db.categoryDao
            .watchCategories(
              filters: provider.filters,
              net: net,
              sumByResetIncrement: false,
            )
            .asyncMap((List<CategoryWithAmount> categories) async {
              // Despite not being watched, the number seems to update anyway
              final uncatAmount =
                  await db.transactionDao
                      .watchTotalAmount(
                        filters: provider.filters,
                        net: net,
                        nullCategory: true,
                      )
                      .first;

              final List<PieChartObject> objects =
                  categories
                      .map(
                        (category) => PieChartObject(
                          name: category.category.name,
                          color: category.category.color,
                          amount: category.amount ?? 0,
                        ),
                      )
                      .toList();

              return [
                ...objects,
                PieChartObject(
                  name: 'Uncategorized',
                  color: Colors.grey,
                  amount: uncatAmount ?? 0,
                ),
              ];
            });
      case ContainerType.goal:
        return db.goalDao
            .watchGoals(filters: provider.filters, net: net)
            .asyncMap((List<GoalWithAchievedAmount> goals) async {
              final noGoals =
                  await db.transactionDao
                      .watchTotalAmount(
                        filters: provider.filters,
                        net: net,
                        nullGoal: true,
                      )
                      .first;

              final List<PieChartObject> objects =
                  goals
                      .map(
                        (goal) => PieChartObject(
                          name: goal.goal.name,
                          color: goal.goal.color,
                          amount: goal.achievedAmount,
                        ),
                      )
                      .toList();
              return [
                ...objects,
                PieChartObject(
                  name: 'No goal',
                  color: Colors.grey,
                  amount: noGoals ?? 0,
                ),
              ];
            });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SizedBox(
        height:
            (48 * 6) +
            16 +
            16, // Height of six buttons (with input padding) + divider height + Padding (both sides)
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: StreamBuilder<List<PieChartObject?>>(
                  stream: _getContainerStream(),
                  builder: (context, categorySnapshot) {
                    if (categorySnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !categorySnapshot.hasData) {
                      return const SizedBox();
                    } else if (categorySnapshot.hasError) {
                      AppLogger().logger.e(
                        'Error loading data: ${categorySnapshot.error}',
                      );
                      return ErrorInset(
                        'Error loading data: ${categorySnapshot.error}',
                      );
                    } else if (!categorySnapshot.hasData ||
                        categorySnapshot.data!.isEmpty) {
                      return ErrorInset.noData;
                    }

                    final data = categorySnapshot.data!;

                    return FutureBuilder<ChartCalculationResult>(
                      future: _calculateChartData(objects: data),
                      builder: (context, dataSnapshot) {
                        // These error widgets should be centered in the row vertically.
                        if (dataSnapshot.hasError) {
                          return ErrorInset(
                            'Something went wrong. Try again later',
                          );
                        } else if (!dataSnapshot.hasData ||
                            dataSnapshot.data!.isEmpty) {
                          return ErrorInset.noData;
                        }

                        return SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Your ${_selectedType.label.toLowerCase()}',
                                textAlign: TextAlign.left,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8.0),
                              _getPieChart(dataSnapshot.data!),
                              const SizedBox(height: 12.0),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      (PieChartCard.estKeyItemHeight *
                                              PieChartCard.maxItems)
                                          .toDouble(),
                                ),
                                child: ListView(
                                  physics: NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  children: dataSnapshot.data!.keyItems,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            IntrinsicWidth(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._buildVerticalTabs<TransactionType?>(
                      PieChartSelectionData.typeList,
                      _selectedType,
                      (newType) {
                        setState(() => _selectedType = newType);

                        final provider = context.read<TransactionProvider>();

                        if (newType.type == null) {
                          provider.removeFilter<TypeFilter>();
                        } else {
                          provider.updateFilter(
                            TypeFilter(newType.type!),
                          );
                        }
                      },
                    ),
                    const Divider(),
                    ..._buildVerticalTabs<ContainerType>(
                      PieChartSelectionData.containerList,
                      _selectedContainer,
                      (newContainer) =>
                          setState(() => _selectedContainer = newContainer),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
