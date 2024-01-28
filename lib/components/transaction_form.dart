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
  TextEditingController titleController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  TextEditingController dateController = TextEditingController();
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
      amountController.text = widget.transaction!.amount.toString();
      notesController.text = widget.transaction!.notes ?? "";
      selectedDate = widget.transaction!.date;
      dateController.text = DateFormat('MM/dd/yyyy').format(selectedDate);
      selectedType = widget.transaction!.type;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    notesController.dispose();
    dateController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> formFields = [
      TextFormField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: "Title",
          ),
          validator: validateTitle),
      TextFormField(
        controller: amountController,
        decoration: const InputDecoration(
          labelText: "Amount",
        ),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        validator: validateAmount,
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
      TextFormField(
        controller: notesController,
        decoration: const InputDecoration(
          labelText: "Notes",
        ),
      ),
      Row(children: [
        Radio<TransactionType>(
          value: TransactionType.expense,
          groupValue: selectedType,
          onChanged: (TransactionType? value) {
            setState(() {
              selectedType = value!;
            });
          },
        ),
        const Text("Expense"),
        Radio<TransactionType>(
          value: TransactionType.income,
          groupValue: selectedType,
          onChanged: (TransactionType? value) {
            setState(() {
              selectedType = value!;
            });
          },
        ),
        const Text("Income"),
      ]),
    ];
    Widget title = const Text("Add Transaction");

    if (widget.mode == TransactionManageMode.edit) {
      title = const Text("Edit Transaction");
    }

    return Form(
      key: _formKey,
      child: AlertDialog(
        title: title,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: formFields,
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
                  if (widget.mode == TransactionManageMode.edit) {
                    transactionProvider.updateTransaction(getTransaction());
                  } else {
                    transactionProvider.addTransaction(getTransaction());
                  }
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
