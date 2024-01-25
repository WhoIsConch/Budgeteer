import 'package:flutter/material.dart';
import 'transactions_list.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTimeRange dateRange =
      DateTimeRange(start: DateTime.now(), end: DateTime.now());

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
          child: IconButton(icon: const Icon(Icons.add), onPressed: () {}),
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
