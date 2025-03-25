import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/components/transaction_form.dart';
import 'package:budget/tools/enums.dart';

class TransactionsPage extends StatefulWidget {
  TransactionsPage(
      {super.key, this.startingDateRange, this.startingTransactionType});

  final DateTimeRange? startingDateRange;
  final TransactionType? startingTransactionType;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  DateTimeRange? dateRange;
  TransactionType? transactionType;
  List types = [null, ...TransactionType.values];
  List typesIcons = [
    const Icon(Icons.all_inclusive),
    const Icon(Icons.remove),
    const Icon(Icons.add)
  ];
  int typeIndex = 0;

  String? searchString;

  Widget datePickerButton() {
    String buttonText = "All Time";

    if (dateRange != null) {
      buttonText =
          "${dateRange!.start.month}/${dateRange!.start.day}/${dateRange!.start.year} - ${dateRange!.end.month}/${dateRange!.end.day}/${dateRange!.end.year}";
    } else if (widget.startingDateRange != null) {
      buttonText =
          "${widget.startingDateRange!.start.month}/${widget.startingDateRange!.start.day}/${widget.startingDateRange!.start.year} - ${widget.startingDateRange!.end.month}/${widget.startingDateRange!.end.day}/${widget.startingDateRange!.end.year}";
    }

    return _getButton(
        icon: Icons.date_range,
        text: buttonText,
        condition: dateRange != null,
        onTap: () {
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

  Future<String?> _showInputDialog(String title) async {
    TextEditingController controller = TextEditingController();

    return showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
              title: Text(title),
              content: TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: "...")),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text("OK"),
                )
              ]);
        });
  }

  Widget _getButton(
      {required bool condition,
      required Function onTap,
      required IconData icon,
      required String text}) {
    if (condition) {
      return GestureDetector(
        onTap: () => onTap(),
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).buttonTheme.colorScheme?.secondaryContainer,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(text,
                  style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .buttonTheme
                          .colorScheme
                          ?.onSecondaryContainer)),
            ),
            Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).buttonTheme.colorScheme?.primary),
                child: Icon(icon,
                    color: Theme.of(context)
                        .buttonTheme
                        .colorScheme
                        ?.onSecondary)),
          ]),
        ),
      );
    }

    return IconButton.outlined(
        onPressed: () => onTap(),
        style: TextButton.styleFrom(
            shape: const CircleBorder(),
            side: BorderSide(color: Theme.of(context).dividerColor)),
        icon: Icon(icon));
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.topRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    datePickerButton(),
                    _getButton(
                      icon: Icons.search,
                      text: searchString ?? "Error",
                      condition:
                          !(searchString == null || searchString!.isEmpty),
                      onTap: () async {
                        String? result = await _showInputDialog("Search");

                        setState(() => searchString = result);
                      },
                    ), // Make search search
                    IconButton.outlined(
                        onPressed: () {
                          setState(() {
                            typeIndex += 1;
                            transactionType = types[typeIndex % 3];
                          });
                        },
                        icon: typesIcons[typeIndex % 3],
                        color: typeIndex % 3 != 0
                            ? Theme.of(context)
                                .buttonTheme
                                .colorScheme
                                ?.onPrimary
                            : null,
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color?>(
                            (states) {
                              if (typeIndex % 3 != 0) {
                                return Theme.of(context)
                                    .buttonTheme
                                    .colorScheme
                                    ?.primary;
                              }

                              return null;
                            },
                          ),
                        ))
                  ],
                ),
              ),
            ),
            Expanded(
                child: TransactionsList(
                    dateRange: dateRange ?? widget.startingDateRange,
                    type: transactionType ?? widget.startingTransactionType)),
          ],
        ),
      ),
    );
  }
}
