import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/views/components/edit_screen.dart';
import 'package:budget/views/components/viewer_screen.dart';
import 'package:budget/views/panels/manage_category.dart';
import 'package:budget/views/panels/manage_goal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ManageTransactionPage extends StatefulWidget {
  const ManageTransactionPage({super.key, this.initialTransaction});

  final Transaction? initialTransaction;

  @override
  State<ManageTransactionPage> createState() => _ManageTransactionPageState();
}

class _ManageTransactionPageState extends State<ManageTransactionPage> {
  final List<String> _validControllers = [
    'amount',
    'title',
    'notes',
    'category',
    'account',
    'goal',
    'date'
  ];
  late final Map<String, TextEditingController> controllers;

  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.income;
  CategoryWithAmount? _selectedCategoryPair;
  Account? _selectedAccount;
  GoalWithAchievedAmount? _selectedGoal;

  HydratedTransaction? hydratedTransaction;

  Transaction? get initialTransaction => widget.initialTransaction;
  bool get isEditing => initialTransaction != null;

  Value<String> getControllerValue(String id) =>
      controllers[id] != null
          ? Value(controllers[id]!.text)
          : const Value.absent();

  TransactionsCompanion _buildTransaction() => TransactionsCompanion(
    id: isEditing ? Value(initialTransaction!.id) : const Value.absent(),
    title: getControllerValue('title'),
    amount: Value(double.parse(controllers['amount']!.text)),
    date: Value(_selectedDate),
    type: Value(_selectedType),
    notes: getControllerValue('notes'),
    category: Value(_selectedCategoryPair?.category.id),
    accountId: Value(_selectedAccount?.id),
    goalId: Value(_selectedGoal?.goal.id),
  );

  void _loadCategory() async {
    // Load the currently selected category into the form
    if (!isEditing) return;
    if (initialTransaction!.category == null) return;

    final categoryPair = await context.read<AppDatabase>().getCategoryById(
      initialTransaction!.category!,
    );

    setState(() {
      _selectedCategoryPair = categoryPair;
      controllers['category']!.text = categoryPair!.category.name;
    });
  }

  void _hydrateTransaction() async {
    if (initialTransaction == null) return;

    var hydrated = await context.read<TransactionDao>().hydrateTransaction(
      initialTransaction!,
    );

    setState(() => hydratedTransaction = hydrated);
  }

  double _getCurrentAmount() =>
      double.tryParse(controllers['amount']!.text) ?? 0;

  @override
  void initState() {
    super.initState();

    Map<String, TextEditingController> tempControllers = {};

    for (var id in _validControllers) {
      tempControllers[id] = TextEditingController();
    }

    if (isEditing) {
      tempControllers['title']!.text = initialTransaction!.title;
      tempControllers['amount']!.text = initialTransaction!.amount
          .toStringAsFixed(2);
      tempControllers['notes']!.text = initialTransaction!.notes ?? '';
      _selectedDate = initialTransaction!.date;
      _selectedType = initialTransaction!.type;

      // Ensure we don't call setState while initState is still working
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCategory();
        // _loadGoal();
        _hydrateTransaction();
      });
    }

    controllers = tempControllers;
    _updateDateControllerText();
  }

  @override
  void dispose() {
    for (var c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateDateControllerText() {
    controllers['date']!.text = DateFormat('MM/dd/yyyy').format(_selectedDate);
  }

  double? _getTotalBalance() {
    if (_selectedCategoryPair == null) return null;

    final originalBalance =
        _selectedCategoryPair!.amount! +
        _selectedCategoryPair!.category.balance!;

    double adjustedBalance = originalBalance;

    if (isEditing &&
        initialTransaction!.category == _selectedCategoryPair!.category.id) {
      // This means we're editing the category and the transaction's amount still
      // exists within the balance. Therefore, we negate it.
      if (initialTransaction!.type == TransactionType.expense) {
        adjustedBalance += initialTransaction!.amount;
      } else {
        adjustedBalance -= initialTransaction!.amount;
      }
    }

    double currentAmount = _getCurrentAmount();

    if (_selectedType == TransactionType.expense) {
      adjustedBalance -= currentAmount;
    } else {
      adjustedBalance += currentAmount;
    }

    return adjustedBalance;
  }

  double? _getTotalGoalBalance() {
    if (_selectedGoal == null) return null;

    double totalRemaining =
        _selectedGoal!.goal.cost - (_selectedGoal!.achievedAmount ?? 0);

    if (isEditing && initialTransaction!.goalId == _selectedGoal!.goal.id) {
      if (initialTransaction!.type == TransactionType.expense) {
        totalRemaining += initialTransaction!.amount;
      } else {
        totalRemaining -= initialTransaction!.amount;
      }
    }

    double currentAmount = _getCurrentAmount();

    if (_selectedType == TransactionType.expense) {
      totalRemaining += currentAmount;
    } else {
      totalRemaining -= currentAmount;
    }

    return totalRemaining;
  }

  String? _getCategorySubtext() {
    if (_selectedCategoryPair == null) return null;

    final adjustedBalance = _getTotalBalance();
    final formattedBalance = formatAmount(adjustedBalance ?? 0);

    String resetText;

    if (_selectedCategoryPair!.category.resetIncrement ==
        CategoryResetIncrement.never) {
      resetText = "Amount doesn't reset";
    } else {
      resetText = _selectedCategoryPair!.category.getTimeUntilNextReset();
    }

    return 'Balance: \$$formattedBalance | $resetText';
  }

  String? _getGoalSubtext() {
    if (_selectedGoal == null) return null;

    final amountRemaining = _getTotalGoalBalance() ?? 0;
    final formattedAmount = formatAmount(amountRemaining);

    String? helperText;

    if (amountRemaining < 0) {
      // substring(1) to remove the minus symbol
      helperText = "You're \$${formattedAmount.substring(1)} past your goal!";
    } else if (amountRemaining == 0) {
      helperText = "You've met your goal! Congrats!";
    } else {
      helperText = '\$$formattedAmount remaining';
    }

    return helperText;
  }

  @override
  Widget build(BuildContext context) {
    return EditFormScreen(
      title: 'Edit transaction',
      onConfirm: () {},
      formFields: [
        MultisegmentButton(
          selected: _selectedType,
          onChanged: (value) => setState(() => _selectedType = value),
          data: [
          SegmentButtonData(label: 'Expense', value: TransactionType.expense),
          SegmentButtonData(label: 'Income', value: TransactionType.income),
        ]),
        CustomInputFormField(label: 'Title', controller: controllers['title']),
        Row(
          spacing: 16.0,
          children: [
            Expanded(
              child: CustomAmountFormField(
                label: 'Amount',
                controller: controllers['amount'],
              ),
            ),
            Expanded(
              child: CustomDatePickerFormField(
                label: 'Date',
                controller: controllers['date'],
                selectedDate: _selectedDate,
                onChanged: (newDate) {
                  if (newDate == null) return;

                  setState(() => _selectedDate = newDate);
                  _updateDateControllerText();
                },
              ),
            ),
          ],
        ),
        FormField<CategoryWithAmount?>(
          autovalidateMode: AutovalidateMode.always,
          validator: (value) {
            print(value);
            if (value == null) return null;
            if (value.category.allowNegatives) return null;

            final totalAmount =
                (value.remainingAmount ?? 0) - _getCurrentAmount();

            if (totalAmount < 0) {
              print("negatory");
              return "Balance can't be negative!";
            }

            return null;
          },
          builder: (state) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StreamBuilder(
                    stream: context.read<AppDatabase>().watchCategories(),
                    builder: (context, snapshot) {
                      final List<CategoryWithAmount?> values =
                          snapshot.hasData ? [...snapshot.data!, null] : [];
                      final labels =
                          values
                              .map((e) => e?.category.name ?? 'No Category')
                              .toList();

                      final bool isDropdownEnabled =
                          snapshot.hasData && values.isNotEmpty;

                      String dropdownLabel = 'Category';
                      if (!snapshot.hasData) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          dropdownLabel = 'Loading';
                        } else {
                          dropdownLabel = 'No categories';
                        }
                      }

                      String? errorText = state.errorText;
                      String? helperText = _getCategorySubtext();

                      if (errorText != null && helperText != null) {
                        errorText = '$errorText\n$helperText';
                        helperText = null;
                      }

                      return CustomDropDownFormField<CategoryWithAmount>(
                        fieldState: state,
                        label: dropdownLabel,
                        initialSelection: _selectedCategoryPair,
                        onChanged:
                            (newCategory) => setState(
                              () => _selectedCategoryPair = newCategory,
                            ),
                        values: values,
                        labels: labels,
                        errorText: errorText,
                        helperText: helperText,
                      );
                    },
                  ),
                ),
                HybridManagerButton(
                  formFieldState: state,
                  icon: Icon(
                    _selectedCategoryPair == null
                        ? Icons.add_circle_outline
                        : Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip:
                      _selectedCategoryPair == null
                          ? 'New category'
                          : 'Edit category',
                  onPressed: () async {
                    final result = await showDialog(
                      context: context,
                      builder:
                          (context) => ManageCategoryDialog(
                            category: _selectedCategoryPair,
                          ),
                    );

                    if (result is String && result.isEmpty) {
                      setState(() {
                        _selectedCategoryPair = null;
                      });
                    } else if (result is CategoryWithAmount) {
                      setState(() {
                        _selectedCategoryPair = result;
                      });
                    }

                    return result;
                  },
                ),
              ],
            );
          },
        ),
        FormField<GoalWithAchievedAmount?>(
          builder: (fieldState) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StreamBuilder(
                    stream: context.read<GoalDao>().watchGoals(),
                    builder: (context, snapshot) {
                      final List<GoalWithAchievedAmount?> goals =
                          snapshot.hasData ? [...snapshot.data!, null] : [];
                      final labels =
                          goals.map((e) => e?.goal.name ?? 'No goal').toList();

                      String dropdownLabel = 'Goal';
                      if (!snapshot.hasData) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          dropdownLabel = 'Loading';
                        } else {
                          dropdownLabel = 'No goals';
                        }
                      }

                      String? helperText = _getGoalSubtext();

                      return CustomDropDownFormField(
                        fieldState: fieldState,
                        label: dropdownLabel,
                        initialSelection: _selectedGoal,
                        onChanged:
                            (newGoal) =>
                                setState(() => _selectedGoal = newGoal),
                        values: goals,
                        labels: labels,
                        helperText: helperText,
                      );
                    },
                  ),
                ),
                HybridManagerButton(
                  formFieldState: fieldState,
                  icon: Icon(
                    _selectedGoal == null
                        ? Icons.add_circle_outline
                        : Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: _selectedGoal == null ? 'New goal' : 'Edit goal',
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => ManageGoalPage(
                              initialGoal: _selectedGoal,
                              returnResult: false,
                            ),
                      ),
                    );

                    if (result is String && result.isEmpty) {
                      setState(() {
                        _selectedGoal = null;
                      });
                    } else if (result is GoalWithAchievedAmount) {
                      setState(() {
                        _selectedGoal = result;
                      });
                    }

                    return result;
                  },
                ),
              ],
            );
          },
        ),
        CustomInputFormField(label: 'Notes', controller: controllers['notes'], maxLines: 3,)
      ],
    );
  }
}
