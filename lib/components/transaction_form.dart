import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/validators.dart';
import 'package:intl/intl.dart';

class TransactionManageDialog extends StatefulWidget {
  const TransactionManageDialog(
      {super.key, this.mode = TransactionManageMode.add, this.transaction});

  final TransactionManageMode mode;
  final Transaction? transaction;

  @override
  State<TransactionManageDialog> createState() =>
      _TransactionManageDialogState();
}

class _TransactionManageDialogState extends State<TransactionManageDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  String? selectedCategory;
  List<String> categories = [];

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
      category: selectedCategory ?? "",
    );

    return transaction;
  }

  @override
  void initState() {
    super.initState();
    dateController.text = DateFormat('MM/dd/yyyy').format(selectedDate);

    // There's probably a better way to do this
    if (widget.mode == TransactionManageMode.edit) {
      titleController.text = widget.transaction!.title;
      amountController.text = widget.transaction!.amount.toStringAsFixed(2);
      notesController.text = widget.transaction!.notes ?? "";
      selectedDate = widget.transaction!.date;
      dateController.text = DateFormat('MM/dd/yyyy').format(selectedDate);
      selectedType = widget.transaction!.type;
      selectedCategory = widget.transaction!.category;
      categoryController.text = selectedCategory ?? "";
    }

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final loadedCategories = await dbHelper.getCategoriesList();

      setState(() {
        categories = loadedCategories;
      });
      print("Set state with categories: $categories");
    } catch (e) {
      print("Failed to load categories: $e");
    }
  }

  Widget getCategoryDropdown() {
    List<DropdownMenuEntry<String>> dropdownEntries = categories
        .map<DropdownMenuEntry<String>>((String cat) => DropdownMenuEntry(
              value: cat,
              label: cat,
            ))
        .toList();

    dropdownEntries
        .add(const DropdownMenuEntry<String>(value: "", label: "No Category"));

    DropdownMenu menu = DropdownMenu<String>(
      inputDecorationTheme: InputDecorationTheme(border: InputBorder.none),
      initialSelection: selectedCategory,
      controller: categoryController,
      requestFocusOnTap: true,
      label: const Text('Category'),
      expandedInsets: EdgeInsets.zero,
      onSelected: (String? category) {
        setState(() {
          print(category);
          selectedCategory = category ?? "";
        });
      },
      dropdownMenuEntries: dropdownEntries,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(width: 4),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child: Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 4, 4), child: menu)),
        VerticalDivider(width: 4, thickness: 4, color: Colors.black),
        Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {},
                ))),
      ]),
    );
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
      getCategoryDropdown(),
      TextFormField(
        controller: notesController,
        style: fieldTextStyle,
        decoration: InputDecoration(labelText: "Notes", labelStyle: labelStyle),
      ),
    ];
    Widget title = const Text("Add Transaction");

    if (widget.mode == TransactionManageMode.edit) {
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
                  if (widget.mode == TransactionManageMode.edit) {
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
