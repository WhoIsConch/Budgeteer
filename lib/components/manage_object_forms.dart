import 'dart:async';
import 'dart:math';

import 'package:budget/components/category_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/validators.dart';
import 'package:intl/intl.dart';

class TransactionManageScreen extends StatefulWidget {
  const TransactionManageScreen(
      {super.key, this.mode = ObjectManageMode.add, this.transaction});

  final ObjectManageMode mode;
  final Transaction? transaction;

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
  Category? selectedCategory;
  double? selectedCategoryTotal;

  DateTime selectedDate = DateTime.now();
  TransactionType selectedType = TransactionType.expense;

  final dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  Transaction getTransaction() {
    // Create a transaction based on the data in the form
    Transaction transaction = Transaction(
      id: widget.transaction?.id,
      title: titleController.text,
      amount: double.parse(amountController.text),
      date: selectedDate,
      notes: notesController.text,
      type: selectedType,
      category: selectedCategory?.name ?? "",
    );

    return transaction;
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
      _loadSelectedCategory(widget.transaction!.category);
    }
  }

  Future<void> _loadSelectedCategory(String name) async {
    Category? category = await dbHelper.getCategory(name);

    _setCategoryInfo(category);
  }

  Future<void> _setCategoryInfo(Category? category) async {
    String catText;
    double? catTotal = selectedCategoryTotal;

    if (category == null) {
      catText = "No Category";
    } else {
      final provider = Provider.of<TransactionProvider>(context, listen: false);

      catText = category.name;
      catTotal =
          await provider.getTotal(category.getDateRange(), category: category);

      catTotal = category.balance + catTotal;

      try {
        Transaction currentTransaction = getTransaction();

        if (currentTransaction.type == TransactionType.expense) {
          catTotal -= currentTransaction.amount;
        } else {
          catTotal += currentTransaction.amount;
        }
      } catch (e) {
        print(e);
      }
    }

    setState(() {
      selectedCategory = category;
      categoryController.text = catText;
      selectedCategoryTotal = catTotal;
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
              _setCategoryInfo(selectedCategory);
              setState(() {
                selectedType = value.first;
              });
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
                    });
                  }
                });
              }),
        ),
      ),
      Consumer<TransactionProvider>(
          builder: (context, transactionProvider, child) => CategoryDropdown(
                categories: transactionProvider.categories,
                onChanged: (category) {
                  setState(() {
                    selectedCategory =
                        transactionProvider.categories.firstWhere(
                      (e) => e.name == category?.name,
                      orElse: () => Category(name: ""),
                    );

                    if (selectedCategory == null ||
                        (selectedCategory != null &&
                            selectedCategory!.name.isEmpty)) {
                      _setCategoryInfo(null);
                    } else {
                      _setCategoryInfo(selectedCategory);
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

    return Scaffold(
      appBar: AppBar(title: title, actions: [
        Consumer<TransactionProvider>(
          builder: (context, transactionProvider, child) => IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  if (widget.mode == ObjectManageMode.edit) {
                    await transactionProvider
                        .updateTransaction(getTransaction());
                  } else {
                    await transactionProvider.addTransaction(getTransaction());
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
        child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                spacing: 24,
                children: formFields,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class CategoryManageDialog extends StatefulWidget {
  const CategoryManageDialog(
      {super.key, this.mode = ObjectManageMode.add, this.category});

  final ObjectManageMode mode;
  final Category? category;

  @override
  State<CategoryManageDialog> createState() => _CategoryManageDialogState();
}

class _CategoryManageDialogState extends State<CategoryManageDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper();

  bool allowNegatives = true;
  CategoryResetIncrement resetIncrement = CategoryResetIncrement.never;
  Color? selectedColor;

  String? validateCategoryTitle(value) {
    String? initialCheck = validateTitle(value);

    if (widget.mode == ObjectManageMode.edit) {
      return initialCheck;
    }

    final provider = Provider.of<TransactionProvider>(context, listen: false);

    bool isUnique = provider.categories.indexWhere(
          (element) => element.name == value,
        ) ==
        -1;

    if (initialCheck == null && isUnique) {
      return null;
    } else if (!isUnique) {
      return "Category already exists";
    } else {
      return initialCheck;
    }
  }

  Category getCategory() {
    return Category(
      id: widget.category?.id,
      name: nameController.text,
      balance: double.parse(amountController.text),
      resetIncrement: resetIncrement,
      allowNegatives: allowNegatives,
      color: selectedColor,
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.mode == ObjectManageMode.edit) {
      nameController.text = widget.category!.name;
      amountController.text = widget.category!.balance.toStringAsFixed(2);
      allowNegatives = widget.category!.allowNegatives;
      resetIncrement = widget.category!.resetIncrement;
      selectedColor = widget.category!.color!;
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = "Create Category";

    // Random category hints for fun
    List<String> categoryHints = [
      "CD Collection",
      "Eating Out",
      "Phone Bill",
      "Video Games",
      "Entertainment",
      "Streaming Services",
      "ChatGPT Credits",
      "Clothes",
      "Car"
    ];

    Random random = Random();
    String categoryHint =
        categoryHints[random.nextInt(categoryHints.length - 1)];

    if (widget.category != null) {
      title = "Edit Category";
    }

    TextButton okButton = TextButton(
      child: const Text("Ok"),
      onPressed: () async {
        if (!_formKey.currentState!.validate()) {
          return;
        }

        final provider =
            Provider.of<TransactionProvider>(context, listen: false);
        Category savedCategory;

        try {
          if (widget.mode == ObjectManageMode.edit) {
            await provider.updateCategory(widget.category!, getCategory());
            savedCategory = getCategory();
          } else {
            savedCategory = await provider.createCategory(getCategory());
          }

          if (context.mounted) {
            Navigator.of(context).pop(savedCategory);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to save transaction: $e")),
            );
          }
        }
      },
    );

    List<Widget> formActions;

    if (widget.mode == ObjectManageMode.add) {
      formActions = [okButton];
    } else {
      formActions = [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
                child: Text("Delete",
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                onPressed: () {
                  final provider =
                      Provider.of<TransactionProvider>(context, listen: false);
                  Category removedCategory = getCategory();
                  int removedIndex = provider.categories
                      .indexWhere((e) => e.id == removedCategory.id);

                  bool undoPressed = false;

                  Navigator.of(context).pop("");

                  provider.removeCategoryFromList(removedIndex);

                  scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
                  scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                          label: "Undo",
                          onPressed: () {
                            undoPressed = true;

                            provider.insertCategoryToList(
                                removedIndex, removedCategory);
                          }),
                      content: Text(
                          "Category \"${removedCategory.name}\" deleted")));

                  Timer(const Duration(seconds: 3, milliseconds: 250), () {
                    scaffoldMessengerKey.currentState!.hideCurrentSnackBar();

                    if (!undoPressed) {
                      provider.removeCategory(removedCategory);
                      print("Removed");
                    }
                  });
                }),
            Row(
              children: [okButton],
            ),
          ],
        )
      ];
    }

    return Form(
      key: _formKey,
      child: AlertDialog(
        title:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ]),
        actions: formActions,
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                        labelText: "Category Name", hintText: categoryHint),
                    validator: validateCategoryTitle,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: false),
                      validator:
                          const AmountValidator(allowZero: true).validateAmount,
                      inputFormatters: [DecimalTextInputFormatter()],
                      controller: amountController,
                      decoration: const InputDecoration(
                          prefixText: "\$",
                          hintText: "500.00",
                          labelText: "Maximum Balance")),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GestureDetector(
                      onTap: () => setState(
                        () => allowNegatives = !allowNegatives,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              semanticLabel: "Allow Negative Balance",
                              value: allowNegatives,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => allowNegatives = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text("Allow Negative Balance")
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Reset every", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  DropdownMenu(
                    expandedInsets: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 16),
                    initialSelection: widget.category?.resetIncrement ??
                        CategoryResetIncrement.never,
                    dropdownMenuEntries: CategoryResetIncrement.values
                        .map(
                          (e) =>
                              DropdownMenuEntry(label: e.getText(), value: e),
                        )
                        .toList(),
                    onSelected: (value) {
                      if (value != null) {
                        setState(() => resetIncrement = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                          title: const Text("Pick a color"),
                          content: MaterialPicker(
                              pickerColor: selectedColor ?? Colors.white,
                              onColorChanged: (newColor) =>
                                  setState(() => selectedColor = newColor)),
                          actions: [
                            TextButton(
                              child: const Text("Ok"),
                              onPressed: () => Navigator.pop(context),
                            )
                          ]),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Color: ",
                            style: TextStyle(fontSize: 18),
                          ),
                          Expanded(
                            child: Container(
                                height: 30,
                                decoration: BoxDecoration(
                                    color: selectedColor ?? Colors.white,
                                    borderRadius: BorderRadius.circular(2))),
                          ),
                        ]),
                  ),
                ]),
          );
        }),
      ),
    );
  }
}
