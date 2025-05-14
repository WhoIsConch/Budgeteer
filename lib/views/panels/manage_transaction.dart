import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/views/panels/manage_category.dart';
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
  final _formKey = GlobalKey<FormState>();

  final List<String> _validControllers = [
    'amount',
    'title',
    'notes',
    'category',
    'account',
    'goal',
  ];
  late final Map<String, TextEditingController> controllers;

  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.expense;
  CategoryWithAmount? _selectedCategoryPair;
  Account? _selectedAccount;
  GoalWithAchievedAmount? _selectedGoal;
  bool _isEditing = false;
  double _currentAmount = 0;

  HydratedTransaction? hydratedTransaction;

  Transaction? get initialTransaction => widget.initialTransaction;
  bool get isViewing => widget.initialTransaction != null;

  String get pageTitle {
    if (_isEditing) return "Edit transation";
    if (isViewing) return "View transaction";
    return "Create transaction";
  }

  void _pickDate(context) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    );

    if (selectedDate != null) {
      setState(() => _selectedDate = selectedDate);
    }
  }

  Value<String> getControllerValue(String id) =>
      controllers[id] != null
          ? Value(controllers[id]!.text)
          : const Value.absent();

  Widget _buildDropdownMenu<T>({
    required String label,
    required List<T> values,
    required List<String> labels,
    required ValueChanged<T?> onChanged,
    TextEditingController? controller,
    bool enabled = true,
    String? errorText,
    String? helperText,
    T? initialSelection,
  }) => DropdownMenu<T>(
    errorText: errorText,
    helperText: helperText,
    enabled: controller != null && enabled,
    controller: controller,
    initialSelection: initialSelection,
    expandedInsets: EdgeInsets.zero,
    dropdownMenuEntries:
        values
            .map(
              (e) =>
                  DropdownMenuEntry(value: e, label: labels[values.indexOf(e)]),
            )
            .toList(),
    label: Text(label),
    onSelected: onChanged,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

  TransactionsCompanion _buildTransaction() => TransactionsCompanion(
    id: isViewing ? Value(initialTransaction!.id) : const Value.absent(),
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
    if (!isViewing) return;
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

  void _updateAmount() => setState(
    () => _currentAmount = double.tryParse(controllers['amount']!.text) ?? 0,
  );

  @override
  void initState() {
    super.initState();

    Map<String, TextEditingController> tempControllers = {};

    for (var id in _validControllers) {
      tempControllers[id] = TextEditingController();
    }

    if (isViewing) {
      tempControllers['title']!.text = initialTransaction!.title;
      tempControllers['amount']!.text = initialTransaction!.amount
          .toStringAsFixed(2);
      tempControllers['notes']!.text = initialTransaction!.notes ?? '';
      _selectedDate = initialTransaction!.date;
      _selectedType = initialTransaction!.type;
      _currentAmount = initialTransaction!.amount;

      // Ensure we don't call setState while initState is still working
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCategory();
        _hydrateTransaction();
      });
    }

    controllers = tempControllers;
  }

  @override
  void dispose() {
    for (var c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double? _getTotalBalance() {
    if (_selectedCategoryPair == null) return null;

    final originalBalance =
        _selectedCategoryPair!.amount! +
        _selectedCategoryPair!.category.balance!;

    double adjustedBalance = originalBalance;

    if (isViewing &&
        initialTransaction!.category == _selectedCategoryPair!.category.id) {
      // This means we're editing the category and the transaction's amount still
      // exists within the balance. Therefore, we negate it.
      if (initialTransaction!.type == TransactionType.expense) {
        adjustedBalance += initialTransaction!.amount;
      } else {
        adjustedBalance -= initialTransaction!.amount;
      }
    }

    double currentAmount = _currentAmount;

    if (_selectedType == TransactionType.expense) {
      adjustedBalance -= currentAmount;
    } else {
      adjustedBalance += currentAmount;
    }

    return adjustedBalance;
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

  Widget _getMenuButton(BuildContext context) {
    final isArchived =
        initialTransaction!.isArchived != null &&
        initialTransaction!.isArchived!;

    return MenuAnchor(
      alignmentOffset: const Offset(-24, 0),
      menuChildren: [
        MenuItemButton(
          child: Text(isArchived ? 'Unarchive' : 'Archive'),
          onPressed:
              () => showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text(
                        "${isArchived ? 'Una' : 'A'}rchive transaction?",
                      ),
                      content: const Text(
                        "Archived transactions don't affect balances and statistics",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            if (!isArchived) {
                              final manager = DeletionManager(context);

                              manager.stageObjectsForArchival<Transaction>([
                                initialTransaction!.id,
                              ]);
                            } else {
                              final transactionDao =
                                  context.read<TransactionDao>();

                              transactionDao.setArchiveTransactions([
                                initialTransaction!.id,
                              ], false);
                            }
                            Navigator.of(context)
                              ..pop()
                              ..pop();
                          },
                          child: Text("${isArchived ? 'Una' : 'A'}rchive"),
                        ),
                      ],
                    ),
              ),
        ),
        MenuItemButton(
          child: const Text('Delete'),
          onPressed:
              () => showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Delete transaction?'),
                      content: const Text(
                        'Are you sure you want to delete this transaction?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            final manager = DeletionManager(context);

                            manager.stageObjectsForDeletion<Transaction>([
                              initialTransaction!.id,
                            ]);
                            Navigator.of(context)
                              ..pop()
                              ..pop();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              ),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, _) => IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          ),
    );
  }

  Widget _getCategoryButton(BuildContext context) {
    return StreamBuilder<List<CategoryWithAmount?>>(
      stream: context.read<AppDatabase>().watchCategories(),
      builder: (context, snapshot) {
        final List<CategoryWithAmount?> values =
            snapshot.hasData ? [...snapshot.data!, null] : [];
        final labels =
            values.map((e) => e?.category.name ?? 'No Category').toList();

        final bool isDropdownEnabled = snapshot.hasData && values.isNotEmpty;

        String dropdownLabel = 'Category';
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            dropdownLabel = 'Loading';
          } else {
            dropdownLabel = 'No categories';
          }
        }

        return FormField<CategoryWithAmount?>(
          initialValue: _selectedCategoryPair,
          autovalidateMode: AutovalidateMode.always,
          validator: (value) {
            if (value == null) return null;

            double? totalBalance = _getTotalBalance();

            if (totalBalance == null) return null;

            if (totalBalance < 0 && !value.category.allowNegatives) {
              return "Balance can't be negative";
            }

            return null;
          },
          builder: (formState) {
            // Ensure the state represents the actual selected value.
            // needed in case the selected pair is changed by something other than the dropdown menu,
            // like _loadCategory or the edit/add category button.
            // Use Future.microtask to avoid calling didChange during build.
            if (formState.value != _selectedCategoryPair) {
              Future.microtask(
                () => formState.didChange(_selectedCategoryPair),
              );
            }

            String? errorText = formState.errorText;
            String? helperText = _getCategorySubtext();

            if (errorText != null && helperText != null) {
              errorText = '$helperText\n$errorText';
            }

            return Row(
              spacing: 4.0,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDropdownMenu<CategoryWithAmount?>(
                    label: dropdownLabel,
                    values: values,
                    labels: labels,
                    errorText: errorText,
                    helperText: helperText,
                    enabled: isDropdownEnabled,
                    initialSelection: formState.value,
                    controller: controllers['category'],
                    onChanged: (pair) {
                      setState(() {
                        _selectedCategoryPair = pair;
                        controllers['category']!.text =
                            pair?.category.name ?? 'No category';
                      });
                      formState.didChange(pair);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: IconButton(
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
                        formState.didChange(null);
                      } else if (result is CategoryWithAmount) {
                        setState(() {
                          _selectedCategoryPair = result;
                        });
                        formState.didChange(result);
                      }
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _getGoalDropdown(BuildContext context) =>
      StreamBuilder<List<GoalWithAchievedAmount>>(
        stream: context.read<GoalDao>().watchGoals(),
        builder: (context, snapshot) {
          final List<GoalWithAchievedAmount?> values =
              snapshot.hasData ? [...snapshot.data!, null] : [];

          String dropdownLabel = "Goal";

          if (values.isEmpty) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              dropdownLabel = "Loading";
            } else {
              dropdownLabel = "No goals";
            }
          }

          return _buildDropdownMenu<GoalWithAchievedAmount?>(
            label: dropdownLabel,
            values: values,
            labels: values.map((e) => e?.goal.name ?? "No goal").toList(),
            initialSelection: _selectedGoal,
            controller: controllers['goal'],
            enabled: values.isNotEmpty,
            onChanged: (goal) {
              setState(() {
                _selectedGoal = goal;
                controllers['goal']!.text = goal?.goal.name ?? '';
              });
            },
          );
        },
      );

  Widget _getForm(BuildContext context) => SingleChildScrollView(
    child: Form(
      autovalidateMode: AutovalidateMode.onUnfocus,
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16.0,
        children: [
          SegmentedButton(
            onSelectionChanged:
                (p0) => setState(() => _selectedType = p0.first),
            selected: {_selectedType},
            segments: const [
              ButtonSegment(
                value: TransactionType.expense,
                label: Text('Expense'),
              ),
              ButtonSegment(
                value: TransactionType.income,
                label: Text('Income'),
              ),
            ],
          ),
          Row(
            spacing: 8.0,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers['title'],
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: validateTitle,
                ),
              ),
            ],
          ),
          Row(
            spacing: 16.0,
            children: [
              Expanded(
                child: TextFormField(
                  onChanged: (_) => _updateAmount(),
                  controller: controllers['amount'],
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: const AmountValidator().validateAmount,
                ),
              ),
              Expanded(
                child: TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: const OutlineInputBorder(),
                    suffixIcon: Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  controller: TextEditingController(
                    text: DateFormat('MM/dd/yyyy').format(_selectedDate),
                  ),
                  onTap: () => _pickDate(context),
                ),
              ),
            ],
          ),
          _getCategoryButton(context),
          _buildDropdownMenu(
            label: 'Account',
            values: [],
            labels: [],
            onChanged: (_) {},
          ),
          _getGoalDropdown(context),
          TextFormField(
            controller: controllers['notes'],
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    ),
  );

  Widget _previewCardItem(
    BuildContext context,
    Icon icon,
    String title,
    String description,
  ) => Row(
    spacing: 8.0,
    children: [
      Padding(padding: EdgeInsets.all(8.0), child: icon),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            Text(
              description,
              style: TextStyle(fontSize: 16),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );

  Widget _getPreview(BuildContext context) {
    if (hydratedTransaction == null) {
      return Center(child: CircularProgressIndicator());
    }

    Color textColor;
    String prefix = '+';

    if (hydratedTransaction!.transaction.type == TransactionType.expense) {
      textColor = getAdjustedColor(
        context,
        Colors.red.harmonizeWith(Theme.of(context).colorScheme.error),
        amount: 0.12,
      );
      prefix = '-';
    } else {
      textColor = Colors.green.harmonizeWith(
        Theme.of(context).colorScheme.primary,
      );
    }

    Widget divider = Divider(color: Theme.of(context).colorScheme.outline);

    List<Widget> previewCards = [
      _previewCardItem(
        context,
        Icon(Icons.calendar_today),
        "Date",
        DateFormat(
          DateFormat.YEAR_ABBR_MONTH_DAY,
        ).format(hydratedTransaction!.transaction.date),
      ),
    ];

    if (hydratedTransaction!.category != null) {
      previewCards.add(divider);
      previewCards.add(
        _previewCardItem(
          context,
          Icon(Icons.category),
          "Category",
          hydratedTransaction!.category!.name,
        ),
      );
    }

    if (hydratedTransaction!.goal != null) {
      previewCards.add(divider);
      previewCards.add(
        _previewCardItem(
          context,
          Icon(Icons.flag),
          "Goal",
          hydratedTransaction!.goal!.name,
        ),
      );
    }

    if (hydratedTransaction!.transaction.notes != null &&
        hydratedTransaction!.transaction.notes!.isNotEmpty) {
      previewCards.add(divider);
      previewCards.add(
        _previewCardItem(
          context,
          Icon(Icons.note),
          "Notes",
          hydratedTransaction!.transaction.notes!,
        ),
      );
    }

    return Column(
      spacing: 16.0,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8.0,
          children: [
            Text(
              "$prefix\$${formatAmount(initialTransaction!.amount, exact: true)}",
              style: Theme.of(
                context,
              ).textTheme.displayMedium!.copyWith(color: textColor),
            ),
            Text(
              initialTransaction!.title,
              style: Theme.of(context).textTheme.titleLarge!,
            ),
          ],
        ),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          margin: EdgeInsets.all(16.0),
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(children: previewCards),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> appBarActions = [
      if (_isEditing)
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final database = context.read<AppDatabase>();
              final currentTransaction = _buildTransaction();

              Transaction savedTran;

              try {
                if (isViewing) {
                  savedTran = await database.updatePartialTransaction(
                    currentTransaction,
                  );
                } else {
                  savedTran = await database.createTransaction(
                    currentTransaction,
                  );
                }

                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder:
                          (_) => ManageTransactionPage(
                            initialTransaction: savedTran,
                          ),
                    ),
                  );
                }

                setState(() => _isEditing = false);
              } catch (e) {
                AppLogger().logger.e('Unable to save transaction: $e');
                context.read<SnackbarProvider>().showSnackBar(
                  const SnackBar(content: Text('Unable to save transaction')),
                );
              }
            }
          },
        ),
      if (!_isEditing)
        IconButton(
          icon: Icon(Icons.edit),
          onPressed: () => setState(() => _isEditing = true),
        ),
      if (!_isEditing) _getMenuButton(context),
    ];

    Widget? leading;

    if (_isEditing) {
      leading = IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => setState(() => _isEditing = false),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Text(pageTitle),
        actions: appBarActions,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _isEditing ? _getForm(context) : _getPreview(context),
      ),
    );
  }
}
