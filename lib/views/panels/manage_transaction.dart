import 'dart:async';

import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/views/components/category_dropdown.dart';
import 'package:budget/services/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:intl/intl.dart';

class ManageTransactionDialog extends StatefulWidget {
  const ManageTransactionDialog(
      {super.key, this.mode = ObjectManageMode.add, this.transaction});

  final ObjectManageMode mode;
  final Transaction? transaction;

  @override
  State<ManageTransactionDialog> createState() =>
      _ManageTransactionDialogState();
}

class _ManageTransactionDialogState extends State<ManageTransactionDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  CategoryWithAmount? selectedCategory;
  double? selectedCategoryTotal;
  bool isLoading = true;
  late Stream<List<CategoryWithAmount>> allCategories;

  DateTime selectedDate = DateTime.now();
  TransactionType selectedType = TransactionType.expense;

  final _formKey = GlobalKey<FormState>();

  TransactionsCompanion getTransaction() {
    // Create a transaction based on the data in the form
    TransactionsCompanion transaction = TransactionsCompanion(
      id: Value.absentIfNull(widget.transaction?.id),
      title: Value(titleController.text),
      amount: Value(double.tryParse(amountController.text) ?? 0),
      date: Value(selectedDate),
      notes: Value(notesController.text),
      type: Value(selectedType),
      category: Value(selectedCategory?.category.id),
    );

    return transaction;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    allCategories = context.watch<AppDatabase>().watchCategories();
  }

  @override
  void initState() {
    super.initState();
    dateController.text = DateFormat('MM/dd/yyyy').format(selectedDate);

    // There's probably a better way to do this
    if (widget.mode == ObjectManageMode.edit) {
      titleController.text = widget.transaction!.title;
      amountController.text = widget.transaction!.amount.toStringAsFixed(2);
      notesController.text = widget.transaction!.notes ?? "";
      selectedDate = widget.transaction!.date;
      dateController.text = DateFormat('MM/dd/yyyy').format(selectedDate);
      selectedType = widget.transaction!.type;
    }

    if (widget.transaction?.category != null) {
      _loadSelectedCategory(widget.transaction!.category!);
    } else {
      isLoading = false;
    }
  }

  Future<void> _loadSelectedCategory(String id) async {
    CategoryWithAmount? category;

    if (id.isNotEmpty) {
      final provider = Provider.of<AppDatabase>(context, listen: false);

      category = await provider.getCategoryById(id);
    }

    _setCategoryInfo(category);
  }

  Future<void> _setCategoryInfo(CategoryWithAmount? categoryPair) async {
    String catText;
    double? catTotal = selectedCategoryTotal;

    if (categoryPair == null) {
      catText = "No Category";
    } else {
      catText = categoryPair.category.name;

      // Get the transaction that's currently represented in the form
      TransactionsCompanion currentTransaction = getTransaction();

      catTotal = categoryPair.amount ?? 0;

      if (widget.transaction != null &&
          widget.transaction!.category == categoryPair.category.id) {
        // This means we're editing a transaction has its amount logged in the selected category.
        // For accurate results, we subtract the original transaction amount from
        // catTotal, then add the current transaction amount.
        catTotal -= widget.transaction!.amount;
      }

      if (currentTransaction.type.value == TransactionType.expense) {
        catTotal -= currentTransaction.amount.value;
      } else {
        catTotal += currentTransaction.amount.value;
      }

      catTotal = (categoryPair.category.balance ?? 0) + catTotal;
    }

    setState(() {
      selectedCategory = categoryPair;
      categoryController.text = catText;
      selectedCategoryTotal = catTotal;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    notesController.dispose();
    dateController.dispose();
    categoryController.dispose();

    super.dispose();
  }

  String? validateTransactionAmount(value) {
    String? initialCheck = const AmountValidator().validateAmount(value);

    if (initialCheck != null) {
      return initialCheck;
    }

    if (selectedCategoryTotal != null &&
        selectedCategoryTotal! < 0 &&
        !selectedCategory!.category.allowNegatives) {
      return "Category balance can't be negative";
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    TextStyle fieldTextStyle = const TextStyle(fontSize: 24, height: 2);
    TextStyle labelStyle = const TextStyle(fontSize: 24);

    List<Widget> formFields = [
      TextFormField(
          style: fieldTextStyle,
          controller: titleController,
          decoration: InputDecoration(
            labelStyle: labelStyle,
            labelText: "Title",
          ),
          validator: validateTitle),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: TextFormField(
              onChanged: (value) => _setCategoryInfo(selectedCategory),
              style: fieldTextStyle,
              controller: amountController,
              decoration: InputDecoration(
                  labelText: "Amount",
                  prefix: const Text("\$"),
                  labelStyle: labelStyle),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              validator: validateTransactionAmount,
              inputFormatters: [DecimalTextInputFormatter()],
            ),
          ),
          const SizedBox(width: 24),
          SegmentedButton(
            style: ButtonStyle(
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)))),
            direction: Axis.vertical,
            selected: {selectedType},
            segments: const [
              ButtonSegment(
                  value: TransactionType.expense, label: Text("Expense")),
              ButtonSegment(
                  value: TransactionType.income, label: Text("Income"))
            ],
            onSelectionChanged: (Set<TransactionType> value) {
              selectedType = value.first;
              _setCategoryInfo(selectedCategory);
            },
          ),
        ],
      ),
      TextFormField(
        readOnly: true,
        controller: dateController,
        style: fieldTextStyle,
        decoration: InputDecoration(
          labelText: "Date",
          labelStyle: labelStyle,
          suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () {
                showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365 * 100)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
                ).then((value) {
                  if (value != null) {
                    selectedDate = value;
                    dateController.text =
                        DateFormat('MM/dd/yyyy').format(selectedDate);
                    _setCategoryInfo(selectedCategory);
                  }
                });
              }),
        ),
      ),
      StreamBuilder<List<CategoryWithAmount>>(
          stream: allCategories,
          builder: (context, snapshot) => CategoryDropdown(
                isLoading: snapshot.connectionState == ConnectionState.waiting,
                categories: snapshot.data ?? [],
                transactionDate: selectedDate,
                onChanged: (category) {
                  _setCategoryInfo(category);
                },
                onDeleted: () => _setCategoryInfo(null),
                selectedCategory: selectedCategory,
              )),
      TextFormField(
        controller: notesController,
        style: fieldTextStyle,
        decoration: InputDecoration(labelText: "Notes", labelStyle: labelStyle),
      ),
    ];
    Widget title = const Text("Add Transaction");

    if (widget.mode == ObjectManageMode.edit) {
      title = const Text("Edit Transaction");
    }

    Widget body =
        StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            spacing: 24,
            children: formFields,
          ),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(title: title, actions: [
        Consumer<AppDatabase>(
          builder: (context, transactionProvider, child) => IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  if (widget.mode == ObjectManageMode.edit) {
                    transactionProvider
                        .updatePartialTransaction(getTransaction());
                  } else {
                    await transactionProvider
                        .createTransaction(getTransaction());
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save transaction: $e')),
                    );
                  }
                }
              }
            },
          ),
        ),
      ]),
      body: Form(
        key: _formKey,
        // title: title,
        child: body,
      ),
    );
  }
}

class TransactionManageScreen extends StatefulWidget {
  final Transaction? transaction;

  const TransactionManageScreen({super.key, this.transaction});

  @override
  State<TransactionManageScreen> createState() =>
      _TransactionManageScreenState();
}

class _TransactionManageScreenState extends State<TransactionManageScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Category? selectedCategory;
  DateTime selectedDate = DateTime.now();
  TransactionType selectedType = TransactionType.expense;

  bool isLoading = true;

  String get titleText =>
      widget.transaction == null ? "Add transaction" : "Update transaction";

  TransactionsCompanion getTransaction() {
    // Create a transaction based on the data in the form
    TransactionsCompanion transaction = TransactionsCompanion(
      id: Value.absentIfNull(widget.transaction?.id),
      title: Value(titleController.text),
      amount: Value(double.tryParse(amountController.text) ?? 0),
      date: Value(selectedDate),
      notes: Value(notesController.text),
      type: Value(selectedType),
      category: Value(selectedCategory?.id),
    );

    return transaction;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titleText), actions: [
        Consumer<AppDatabase>(
          builder: (context, transactionProvider, child) => IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  if (widget.transaction != null) {
                    transactionProvider
                        .updatePartialTransaction(getTransaction());
                  } else {
                    await transactionProvider
                        .createTransaction(getTransaction());
                  }

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    context.read<SnackbarProvider>().showSnackBar(SnackBar(
                          content: Text('Failed to save transaction: $e'),
                        ));
                  }
                }
              }
            },
          ),
        ),
      ]),
    );
  }
}
