import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/validators.dart';
import 'package:intl/intl.dart';

enum TransactionManageMode { add, edit }

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

  Transaction getTransaction() {
    Transaction transaction = Transaction(
      id: widget.transaction?.id ?? 0,
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

    if (widget.mode == TransactionManageMode.edit) {
      titleController.text = widget.transaction!.title;
      amountController.text = widget.transaction!.amount.toString();
      notesController.text = widget.transaction!.notes ?? "";
      selectedDate = widget.transaction!.date;
      dateController.text = DateFormat('MM/dd/yyyy').format(selectedDate);
    }
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
