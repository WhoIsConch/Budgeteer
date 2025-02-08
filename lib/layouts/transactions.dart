import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/components/transaction_form.dart';
import 'package:budget/tools/enums.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, this.startingDateRange, this.type});

  final DateTimeRange? startingDateRange;
  final TransactionType? type;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTimeRange? dateRange;

  Widget datePickerButton() {
    String buttonText = "All Transactions";

    if (dateRange != null) {
      buttonText =
          "${dateRange!.start.month}/${dateRange!.start.day}/${dateRange!.start.year} - ${dateRange!.end.month}/${dateRange!.end.day}/${dateRange!.end.year}";
    } else if (widget.startingDateRange != null) {
      buttonText =
          "${widget.startingDateRange!.start.month}/${widget.startingDateRange!.start.day}/${widget.startingDateRange!.start.year} - ${widget.startingDateRange!.end.month}/${widget.startingDateRange!.end.day}/${widget.startingDateRange!.end.year}";
    }

    return TextButton(
        child: Text(buttonText,
            style: TextStyle(
              fontSize: Theme.of(context).textTheme.headlineSmall!.fontSize,
            )),
        onPressed: () {
          showDateRangePicker(
                  context: context,
                  initialDateRange: dateRange,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365 * 10)),
                  lastDate: DateTime.now())
              .then((value) {
            setState(() {
              dateRange = value;
            });
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
                      return const TransactionManageDialog();
                    });
              }),
        )
      ]),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(child: datePickerButton()),
                  IconButton.outlined(
                      onPressed: () {},
                      icon: const Icon(Icons.search)), // TODO: Implement Search
                ],
              ),
            ),
            Expanded(
                child: TransactionsList(
                    dateRange: dateRange ?? widget.startingDateRange,
                    type: widget.type)),
          ],
        ),
      ),
    );
  }
}
