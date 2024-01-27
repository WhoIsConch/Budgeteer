import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/tools/api.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, this.startingDateRange});

  final DateTimeRange? startingDateRange;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late DateTimeRange dateRange;

  @override
  void initState() {
    super.initState();
    dateRange = widget.startingDateRange ??
        DateTimeRange(start: DateTime.now(), end: DateTime.now());
    ;
  }

  Widget datePickerButton() {
    return TextButton(
        child: Text(
            "${dateRange.start.month}/${dateRange.start.day}/${dateRange.start.year} - ${dateRange.end.month}/${dateRange.end.day}/${dateRange.end.year}",
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.headlineSmall!.fontSize,
            )),
        onPressed: () {
          showDateRangePicker(
                  context: context,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365 * 10)),
                  lastDate: DateTime.now())
              .then((value) {
            if (value != null) {
              setState(() {
                dateRange = value;
              });
            }
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Transactions"), actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
          child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (context) {
                      return AddTransactionDialogue();
                    });
              }),
        )
      ]),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            datePickerButton(),
            const Expanded(child: TransactionsList()),
          ],
        ),
      ),
    );
  }
}

class AddTransactionDialogue extends StatefulWidget {
  const AddTransactionDialogue({super.key});

  @override
  State<AddTransactionDialogue> createState() => _AddTransactionDialogueState();
}

class _AddTransactionDialogueState extends State<AddTransactionDialogue> {
  TextEditingController titleController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime selectedDate = DateTime.now();

  Transaction getTransaction() {
    Transaction transaction = Transaction(
      id: 0,
      title: titleController.text,
      amount: double.parse(amountController.text),
      date: selectedDate,
      notes: notesController.text,
    );

    return transaction;
  }

  @override
  void initState() {
    super.initState();
    dateController.text = DateFormat('MM/dd/yyyy').format(selectedDate);
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    notesController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add Transaction"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: "Title",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please enter a title";
                    } else if (value.length > 50) {
                      return "Title must be less than 50 characters";
                    }
                    return null;
                  }),
              TextFormField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: "Amount",
                ),
                keyboardType: TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                validator: ((value) {
                  if (value == null || value.isEmpty) {
                    return "Please enter an amount";
                  } else if (double.tryParse(value) == null && value != "-") {
                    return "Please enter a valid amount";
                  }
                  return null;
                }),
              ),
              TextFormField(
                readOnly: true,
                controller: dateController,
                decoration: InputDecoration(
                  labelText: "Date",
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () {
                        showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365 * 10)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 10)),
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
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: "Notes",
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text("Cancel"),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        Consumer<TransactionProvider>(
          builder: (context, transactionProvider, child) => TextButton(
            child: const Text("Save"),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                transactionProvider.addTransaction(getTransaction());
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      ],
    );
  }
}
