import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/views/panels/manage_category.dart';
import 'package:drift/drift.dart' show Value;
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
    "amount",
    "title",
    "notes",
    "category",
    "account",
    "goal"
  ];
  late final Map<String, TextEditingController> controllers;

  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.expense;
  CategoryWithAmount? _selectedCategoryPair;
  Account? _selectedAccount;
  Goal? _selectedGoal;

  Transaction? get initialTransaction => widget.initialTransaction;

  bool get isEditing => widget.initialTransaction != null;

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

  Value<String> getControllerValue(String id) => controllers[id] != null
      ? Value(controllers[id]!.text)
      : const Value.absent();

  DropdownMenu _buildDropdownMenu<T>({
    required String label,
    required List<T> values,
    required List<String> labels,
    required ValueChanged<T?> onChanged,
    TextEditingController? controller,
    T? initialSelection,
  }) => // Dart formatter PLEASE this is so ugly
      DropdownMenu<T>(
        enabled: controller != null,
        controller: controller,
        initialSelection: initialSelection,
        expandedInsets: EdgeInsets.zero,
        dropdownMenuEntries: values
            .map(
              (e) =>
                  DropdownMenuEntry(value: e, label: labels[values.indexOf(e)]),
            )
            .toList(),
        label: Text(label),
        onSelected: onChanged,
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
      );

  TransactionsCompanion _buildTransaction() => TransactionsCompanion(
        id: isEditing ? Value(initialTransaction!.id) : const Value.absent(),
        title: getControllerValue("title"),
        amount: Value(double.parse(controllers["amount"]!.text)),
        date: Value(_selectedDate),
        type: Value(_selectedType),
        notes: getControllerValue("notes"),
        category: Value(_selectedCategoryPair?.category.id),
        accountId: Value(_selectedAccount?.id),
        goalId: Value(_selectedGoal?.id),
      );

  void _loadCategory() async {
    // Load the currently selected category into the form
    if (!isEditing) return;
    if (initialTransaction!.category == null) return;

    final categoryPair = await context
        .read<AppDatabase>()
        .getCategoryById(initialTransaction!.category!);

    setState(() {
      _selectedCategoryPair = categoryPair;
      controllers["category"]!.text = categoryPair!.category.name;
    });
  }

  @override
  void initState() {
    super.initState();

    Map<String, TextEditingController> tempControllers = {};

    for (var id in _validControllers) {
      tempControllers[id] = TextEditingController();
    }

    if (isEditing) {
      tempControllers["title"]!.text = initialTransaction!.title;
      tempControllers["amount"]!.text =
          initialTransaction!.amount.toStringAsFixed(2);
      tempControllers["notes"]!.text = initialTransaction!.notes ?? "";

      // Ensure we don't call setState while initState is still working
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCategory();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(isEditing ? "Edit transaction" : "Add transaction"),
            actions: [
              IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final database = context.read<AppDatabase>();
                      final currentTransaction = _buildTransaction();

                      try {
                        if (isEditing) {
                          database.updatePartialTransaction(currentTransaction);
                        } else {
                          database.createTransaction(currentTransaction);
                        }

                        Navigator.of(context).pop();
                      } catch (e) {
                        AppLogger().logger.e("Unable to save transaction: $e");
                        context
                            .read<SnackbarProvider>()
                            .showSnackBar(const SnackBar(
                              content: Text("Unable to save transaction"),
                            ));
                      }
                    }
                  })
            ]),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SingleChildScrollView(
            child: Form(
              autovalidateMode: AutovalidateMode.onUnfocus,
              key: _formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16.0,
                  children: [
                    SegmentedButton(
                      onSelectionChanged: (p0) =>
                          setState(() => _selectedType = p0.first),
                      selected: {_selectedType},
                      segments: const [
                        ButtonSegment(
                            value: TransactionType.expense,
                            label: Text("Expense")),
                        ButtonSegment(
                            value: TransactionType.income,
                            label: Text("Income"))
                      ],
                    ),
                    TextFormField(
                      controller: controllers["amount"],
                      decoration: InputDecoration(
                          labelText: "Amount",
                          prefixIcon: Icon(Icons.attach_money,
                              color: Theme.of(context).colorScheme.primary),
                          border: const OutlineInputBorder()),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: const AmountValidator().validateAmount,
                    ),
                    TextFormField(
                      controller: controllers["title"],
                      decoration: const InputDecoration(
                          labelText: "Title", border: OutlineInputBorder()),
                      validator: validateTitle,
                    ),
                    TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Date",
                          border: const OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        controller: TextEditingController(
                            text:
                                DateFormat('MM/dd/yyyy').format(_selectedDate)),
                        onTap: () => _pickDate(context)),
                    Row(spacing: 8.0, children: [
                      Expanded(
                        child: StreamBuilder<List<CategoryWithAmount?>>(
                            stream:
                                context.read<AppDatabase>().watchCategories(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildDropdownMenu(
                                      label: "Loading",
                                      values: [],
                                      labels: [],
                                      onChanged: (_) {});
                                }
                                return _buildDropdownMenu(
                                    label: "No categories",
                                    values: [],
                                    labels: [],
                                    onChanged: (_) {});
                              }

                              final List<CategoryWithAmount?> values = [
                                ...snapshot.data!,
                                null
                              ];
                              final labels = values
                                  .map(
                                    (e) => e?.category.name ?? "No Category",
                                  )
                                  .toList();

                              return _buildDropdownMenu<CategoryWithAmount?>(
                                  label: "Category",
                                  values: values,
                                  labels: labels,
                                  initialSelection: _selectedCategoryPair,
                                  controller: controllers["category"],
                                  onChanged: (pair) => setState(() {
                                        _selectedCategoryPair = pair;
                                        controllers["category"]!.text =
                                            pair?.category.name ??
                                                "No category";
                                      }));
                            }),
                      ),
                      IconButton(
                        icon: Icon(
                            _selectedCategoryPair == null
                                ? Icons.add_circle_outline
                                : Icons.edit,
                            color: Theme.of(context).colorScheme.primary),
                        tooltip: _selectedCategoryPair == null
                            ? "New category"
                            : "Edit category",
                        onPressed: () async {
                          final result = await showDialog(
                              context: context,
                              builder: (context) => ManageCategoryDialog(
                                  category: _selectedCategoryPair));

                          if (result is String && result.isEmpty) {
                            setState(() => _selectedCategoryPair = null);
                          } else if (result is CategoryWithAmount) {
                            setState(() => _selectedCategoryPair = result);
                          }
                        },
                      ),
                    ]),
                    _buildDropdownMenu(
                        label: "Account",
                        values: [],
                        labels: [],
                        onChanged: (_) {}),
                    _buildDropdownMenu(
                        label: "Goal",
                        values: [],
                        labels: [],
                        onChanged: (_) {}),
                    TextFormField(
                      controller: controllers["notes"],
                      decoration: const InputDecoration(
                          labelText: "Notes (optional)",
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true),
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                    )
                  ]),
            ),
          ),
        ));
  }
}
