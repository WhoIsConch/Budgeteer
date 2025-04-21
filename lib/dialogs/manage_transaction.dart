import 'dart:async';

import 'package:budget/components/category_dropdown.dart';
import 'package:budget/database/app_database.dart';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/validators.dart';
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
  Category? selectedCategory;
  double? selectedCategoryTotal;
  bool isLoading = true;
  late Stream<List<Category>> allCategories;

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
      category: Value.absentIfNull(selectedCategory?.id),
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
    Category? category;

    if (id.isNotEmpty) {
      final provider = Provider.of<AppDatabase>(context, listen: false);

      category = await provider.getCategoryById(id);
    }

    _setCategoryInfo(category);
  }

  Future<void> _setCategoryInfo(Category? category) async {
    String catText;
    double? catTotal = selectedCategoryTotal;

    if (category == null) {
      catText = "No Category";
    } else {
      final provider = Provider.of<TransactionDao>(context, listen: false);

      catText = category.name;

      // Get the transaction that's currently represented in the form
      TransactionsCompanion currentTransaction = getTransaction();

      RelativeDateRange? categoryRelRange =
          category.resetIncrement.relativeDateRange;

      catTotal = await provider.getTotalAmount(
          dateRange: categoryRelRange
              ?.getRange(
                  fullRange: true, fromDate: currentTransaction.date.value)
              .makeInclusive(),
          category: category);

      catTotal = 0;

      if (widget.transaction != null) {
        // This means we're editing.
        // For accurate results, we subtract the original transaction amount from
        // catTotal, then add the current transaction amount.
        catTotal -= widget.transaction!.amount;
      }

      if (currentTransaction.type.value == TransactionType.expense) {
        catTotal -= currentTransaction.amount.value;
      } else {
        catTotal += currentTransaction.amount.value;
      }

      catTotal = category.balance ?? 0 + catTotal;
    }

    setState(() {
      selectedCategory = category;
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
        !selectedCategory!.allowNegatives) {
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
              setState(() {
                selectedType = value.first;
              });
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
                      DateTime.now().subtract(const Duration(days: 365 * 10)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                ).then((value) {
                  if (value != null) {
                    setState(() {
                      selectedDate = value;
                      dateController.text =
                          DateFormat('MM/dd/yyyy').format(selectedDate);
                      _setCategoryInfo(selectedCategory);
                    });
                  }
                });
              }),
        ),
      ),
      StreamBuilder(
          stream: allCategories,
          builder: (context, snapshot) => CategoryDropdown(
                isLoading: snapshot.connectionState == ConnectionState.waiting,
                categories: snapshot.data ?? [],
                transactionDate: selectedDate,
                onChanged: (category) {
                  // TODO: Make category info update when the category is edited
                  setState(() {
                    if (category != null) {
                      selectedCategory = category;
                      _setCategoryInfo(category);
                    } else {
                      _setCategoryInfo(null);
                    }
                  });
                },
                selectedCategory: selectedCategory,
                selectedCategoryTotal: selectedCategoryTotal,
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
