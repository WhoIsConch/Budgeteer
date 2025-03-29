import 'dart:math';

import 'package:flutter/material.dart';
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

  final dbHelper = DatabaseHelper();

  final _formKey = GlobalKey<FormState>();
  DateTime selectedDate = DateTime.now();
  TransactionType selectedType = TransactionType.expense;

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

    if (category == null) {
      return;
    }

    setState(() {
      selectedCategory = category;
      categoryController.text = category.name;
    });
  }

  Widget getCategoryDropdown(List<Category> categories) {
    List<DropdownMenuEntry<String>> dropdownEntries = categories
        .map<DropdownMenuEntry<String>>((Category cat) => DropdownMenuEntry(
              value: cat.name,
              label: cat.name,
            ))
        .toList();

    dropdownEntries
        .add(const DropdownMenuEntry<String>(value: "", label: "No Category"));

    DropdownMenu menu = DropdownMenu<String>(
      inputDecorationTheme: InputDecorationTheme(border: InputBorder.none),
      initialSelection: selectedCategory?.name ?? "",
      controller: categoryController,
      requestFocusOnTap: true,
      label: const Text('Category'),
      expandedInsets: EdgeInsets.zero,
      onSelected: (String? categoryName) {
        if (categoryName == null || categoryName.isEmpty) {
          setState(() => selectedCategory = null);
          return;
        }

        setState(() {
          print(categoryName);
          selectedCategory =
              categories.firstWhere((e) => e.name == categoryName);
        });
      },
      dropdownMenuEntries: dropdownEntries,
    );

    Container categorySelector = Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border(
            bottom: BorderSide(
          width: 1,
          color: Theme.of(context).dividerColor,
        )),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4), child: menu)),
        Container(width: 1, height: 64, color: Theme.of(context).dividerColor),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: IconButton(
              icon: selectedCategory == null
                  ? const Icon(Icons.add)
                  : const Icon(Icons.edit),
              onPressed: () {
                if (selectedCategory == null) {
                  showDialog(
                      context: context,
                      builder: (context) => CategoryManageDialog(
                            category: selectedCategory,
                            mode: selectedCategory == null
                                ? ObjectManageMode.add
                                : ObjectManageMode.edit,
                          ));
                }
              },
            )),
      ]),
    );

    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(width: 1, color: Theme.of(context).dividerColor)),
        child: Column(
          children: [
            categorySelector,
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("Hello"),
            ),
          ],
        ));
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

  @override
  Widget build(BuildContext context) {
    TextStyle fieldTextStyle = TextStyle(fontSize: 24, height: 2);
    TextStyle labelStyle = TextStyle(fontSize: 24);

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
              style: fieldTextStyle,
              controller: amountController,
              decoration: InputDecoration(
                  labelText: "Amount",
                  prefix: const Text("\$"),
                  labelStyle: labelStyle),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: false),
              validator: validateAmount,
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
          builder: (context, transactionProvider, child) =>
              getCategoryDropdown(transactionProvider.categories)),
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
            icon: Icon(Icons.check),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  if (widget.mode == ObjectManageMode.edit) {
                    await transactionProvider
                        .updateTransaction(getTransaction());
                  } else {
                    await transactionProvider.addTransaction(getTransaction());
                  }
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save transaction: $e')),
                  );
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

  Category getCategory() {
    return Category(
      id: widget.category?.id,
      name: nameController.text,
      balance: double.parse(amountController.text),
      resetIncrement: resetIncrement,
      allowNegatives: allowNegatives,
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

    return Form(
      key: _formKey,
      child: AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
              child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text("Ok"),
            onPressed: () async {
              try {
                if (_formKey.currentState!.validate()) {
                  if (widget.mode == ObjectManageMode.edit) {
                    await dbHelper.updateCategory(getCategory());
                  } else {
                    await dbHelper.createCategory(getCategory());
                  }

                  Navigator.of(context).pop();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to save transaction: $e")),
                );
              }
            },
          ),
        ],
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                      labelText: "Category Name", hintText: categoryHint),
                  validator: validateTitle,
                ),
                const SizedBox(height: 16),
                TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: false),
                    validator: validateAmount,
                    inputFormatters: [DecimalTextInputFormatter()],
                    controller: amountController,
                    decoration: const InputDecoration(
                        prefixText: "\$",
                        hintText: "\500.00",
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
                        (e) => DropdownMenuEntry(label: e.getText(), value: e),
                      )
                      .toList(),
                  onSelected: (value) {
                    if (value != null) {
                      setState(() => resetIncrement = value);
                    }
                  },
                ),
              ]);
        }),
      ),
    );
  }
}
