import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/appui/accounts/manage_account.dart';
import 'package:budget/appui/categories/manage_category.dart';
import 'package:budget/appui/goals/manage_goal.dart';
import 'package:budget/appui/transactions/view_transaction.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ManageTransactionPage extends StatefulWidget {
  final bool returnResult;
  final Transaction? initialTransaction;

  const ManageTransactionPage({
    super.key,
    this.initialTransaction,
    this.returnResult = false,
  });

  @override
  State<ManageTransactionPage> createState() => _ManageTransactionPageState();
}

class _ManageTransactionPageState extends State<ManageTransactionPage> {
  final List<String> _validControllers = ['amount', 'title', 'notes', 'date'];
  late final Map<String, TextEditingController> controllers;

  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.income;
  CategoryWithAmount? _selectedCategoryPair;
  AccountWithTotal? _selectedAccount;
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
    accountId: Value(_selectedAccount?.account.id),
    goalId: Value(_selectedGoal?.goal.id),
  );

  void _hydrateTransaction() async {
    if (!isEditing) return;

    var hydrated = await context
        .read<AppDatabase>()
        .transactionDao
        .hydrateTransaction(initialTransaction!);

    if (hydrated.categoryPair != null) {
      setState(() {
        _selectedCategoryPair = hydrated.categoryPair;
      });
    }

    if (hydrated.goalPair != null) {
      setState(() {
        _selectedGoal = hydrated.goalPair;
      });
    }

    if (hydrated.accountPair != null) {
      setState(() {
        _selectedAccount = hydrated.accountPair;
      });
    }

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

  double? _getTotalAccountBalance() {
    if (_selectedAccount == null) return null;

    double adjustedTotal = _selectedAccount!.total;

    if (isEditing &&
        initialTransaction!.accountId == _selectedAccount!.account.id) {
      if (initialTransaction!.type == TransactionType.expense) {
        adjustedTotal -= initialTransaction!.amount;
      } else {
        adjustedTotal += initialTransaction!.amount;
      }
    }

    double currentAmount = _getCurrentAmount();

    if (_selectedType == TransactionType.expense) {
      adjustedTotal -= currentAmount;
    } else {
      adjustedTotal += currentAmount;
    }

    return adjustedTotal;
  }

  double? _getTotalCategoryBalance() {
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
        _selectedGoal!.goal.cost - (_selectedGoal!.achievedAmount);

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

    final adjustedBalance = _getTotalCategoryBalance();
    final formattedBalance = formatAmount(adjustedBalance ?? 0);

    String resetText;

    if (_selectedCategoryPair!.category.resetIncrement ==
        CategoryResetIncrement.never) {
      resetText = "Amount doesn't reset";
    } else {
      resetText = _selectedCategoryPair!.category.getTimeUntilNextReset();
    }

    return 'Remaining: \$$formattedBalance | $resetText';
  }

  @override
  Widget build(BuildContext context) {
    return EditFormScreen(
      title: 'Edit transaction',
      onConfirm: () async {
        final newTransaction = _buildTransaction();

        final db = context.read<AppDatabase>();
        HydratedTransaction result;
        Transaction raw;

        if (isEditing) {
          raw = await db.transactionDao.updateTransaction(newTransaction);
        } else {
          raw = await db.transactionDao.createTransaction(newTransaction);
        }

        result = await db.transactionDao.hydrateTransaction(raw);

        if (context.mounted) {
          if (!widget.returnResult) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ViewTransaction(transactionData: result),
              ),
            );
          } else {
            Navigator.of(context).pop(result);
          }
        }
      },
      formFields: [
        MultisegmentButton(
          selected: _selectedType,
          onChanged: (value) => setState(() => _selectedType = value),
          data: [
            SegmentButtonData(label: 'Expense', value: TransactionType.expense),
            SegmentButtonData(label: 'Income', value: TransactionType.income),
          ],
        ),
        TextInputEditField(
          label: 'Title',
          controller: controllers['title'],
          validator: validateTitle,
        ),
        Row(
          spacing: 16.0,
          children: [
            Expanded(
              child: AmountEditField(
                label: 'Amount',
                controller: controllers['amount'],
              ),
            ),
            Expanded(
              child: DatePickerEditField(
                label: 'Date',
                controller: controllers['date'],
                selectedDate: _selectedDate,
                onChanged: (response) {
                  if (response.cancelled || response.value == null) return;

                  setState(() => _selectedDate = response.value!);
                  _updateDateControllerText();
                },
              ),
            ),
          ],
        ),
        FormField<CategoryWithAmount?>(
          autovalidateMode: AutovalidateMode.always,
          validator: (value) {
            if (value == null) return null;
            if (value.category.allowNegatives) return null;

            final totalAmount =
                (value.remainingAmount ?? 0) - _getCurrentAmount();

            if (totalAmount < 0) {
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
                    stream:
                        context
                            .read<AppDatabase>()
                            .categoryDao
                            .watchCategories(),
                    builder: (context, snapshot) {
                      final List<CategoryWithAmount?> values =
                          snapshot.hasData ? [...snapshot.data!, null] : [];
                      final labels =
                          values
                              .map((e) => e?.category.name ?? 'No Category')
                              .toList();

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

                      return DropdownEditField<CategoryWithAmount>(
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
                            returnResult: true,
                          ),
                    );

                    if (result is CategoryWithAmount) {
                      state.didChange(result);
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
                    stream: context.read<AppDatabase>().goalDao.watchGoals(),
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

                      String? helperText = _selectedGoal?.getStatus(
                        totalBalance: _getTotalGoalBalance(),
                      );

                      return DropdownEditField(
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
                              returnResult: true,
                            ),
                      ),
                    );

                    if (result is GoalWithAchievedAmount) {
                      fieldState.didChange(result);
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
        FormField<AccountWithTotal?>(
          builder: (fieldState) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StreamBuilder(
                    stream:
                        context.read<AppDatabase>().accountDao.watchAccounts(),
                    builder: (context, snapshot) {
                      final List<AccountWithTotal?> accounts =
                          snapshot.hasData ? [...snapshot.data!, null] : [];
                      final labels =
                          accounts
                              .map((a) => a?.account.name ?? 'No account')
                              .toList();

                      String dropdownLabel = 'Account';

                      if (!snapshot.hasData) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          dropdownLabel = 'Loading';
                        } else {
                          dropdownLabel = 'No accounts';
                        }
                      }

                      String? formattedAmount;
                      final total = _getTotalAccountBalance();

                      if (total != null) {
                        String prefix = total.isNegative ? '-' : '';
                        formattedAmount =
                            '$prefix\$${formatAmount(total.abs(), exact: true)}';
                      }

                      return DropdownEditField(
                        fieldState: fieldState,
                        label: dropdownLabel,
                        initialSelection: _selectedAccount,
                        controller: controllers['account'],
                        onChanged:
                            (newAccount) =>
                                setState(() => _selectedAccount = newAccount),
                        values: accounts,
                        labels: labels,
                        helperText: formattedAmount,
                      );
                    },
                  ),
                ),
                HybridManagerButton(
                  icon: Icon(
                    _selectedAccount == null
                        ? Icons.add_circle_outline
                        : Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip:
                      _selectedAccount == null ? 'New account' : 'Edit account',
                  onPressed: () async {
                    print("Pressed");
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => ManageAccountForm(
                              initialAccount: _selectedAccount,
                            ),
                      ),
                    );

                    print("After");

                    if (result is AccountWithTotal) {
                      print(result);
                      fieldState.didChange(result);
                      setState(() {
                        _selectedAccount = result;
                      });
                    }
                  },
                ),
              ],
            );
          },
        ),
        TextInputEditField(
          label: 'Notes',
          controller: controllers['notes'],
          maxLines: 3,
        ),
      ],
    );
  }
}
