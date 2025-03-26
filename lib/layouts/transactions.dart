import 'package:budget/tools/api.dart';
import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/tools/enums.dart';

enum AmountFilterType { greaterThan, lessThan, exactly }

class AmountFilter {
  final AmountFilterType? type;
  final double? value;

  AmountFilter({this.type, this.value});
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage(
      {super.key, this.startingDateRange, this.startingTransactionType});

  final DateTimeRange? startingDateRange;
  final TransactionType? startingTransactionType;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final _dbHelper = DatabaseHelper();

  DateTimeRange? dateRange;
  TransactionType? transactionType;
  List types = [null, ...TransactionType.values];
  List typesIcons = [
    const Icon(Icons.all_inclusive),
    const Icon(Icons.remove),
    const Icon(Icons.add)
  ];
  int typeIndex = 0;
  AmountFilter? amountFilter;

  String searchString = "";
  List<String> allCategories = <String>[];
  List<String> selectedCategories = [];

  bool resultsAreFiltered() {
    return searchString.isNotEmpty ||
        dateRange != null ||
        allCategories.isNotEmpty ||
        typeIndex % 3 != 0 ||
        selectedCategories.isNotEmpty ||
        amountFilter != null;
  }

  Widget datePickerButton() {
    String buttonText = "All Time";

    if (dateRange != null) {
      buttonText =
          "${dateRange!.start.month}/${dateRange!.start.day}/${dateRange!.start.year} - ${dateRange!.end.month}/${dateRange!.end.day}/${dateRange!.end.year}";
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

  Future<List<String>?> _showCategoryInputDialog() async {
    // Shows a dropdown of all available categories.
    // Returns a list of selected categories.
    // This shows an AlertDialog with nothing in it other than a dropdown
    // which a user can select multiple categories from.

    List<String> categories = await _dbHelper.getUniqueCategories();

    return showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text("Select Categories"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (BuildContext context, int index) {
                    final category = categories[index];
                    return CheckboxListTile(
                      title: Text(category),
                      value: selectedCategories.contains(category),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value != null) {
                            if (value) {
                              selectedCategories.add(category);
                            } else {
                              selectedCategories.remove(category);
                            }
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(selectedCategories);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<AmountFilter?> _showAmountFilterDialog() async {
    // Shows a dialog inline with a dropdown showing the filter type first,
    // then the amount as an input.
    TextEditingController controller = TextEditingController();
    controller.text = amountFilter?.value.toString() ?? "";
    amountFilter = amountFilter ?? AmountFilter(type: AmountFilterType.exactly);

    return showDialog<AmountFilter>(
        context: context,
        builder: (context) {
          return AlertDialog(
              title: const Text("Filter by Amount"),
              content: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    DropdownMenu(
                      width: 150,
                      initialSelection:
                          amountFilter?.type ?? AmountFilterType.exactly,
                      label: const Text("Type"),
                      dropdownMenuEntries: AmountFilterType.values
                          .map((value) => DropdownMenuEntry(
                              value: value, label: value.name))
                          .toList(),
                      onSelected: (AmountFilterType? value) => setState(() {
                        amountFilter = AmountFilter(type: value);
                      }),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                                hintText: "Amount", prefixText: "\$ ")),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                      context,
                      AmountFilter(
                          type: amountFilter?.type,
                          value: double.parse(controller.text))),
                  child: const Text("OK"),
                )
              ]);
        });
  }

  Future<String?> _showTextInputDialog(String title) async {
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

  Widget _getButton({
    required bool condition,
    required Function onTap,
    required IconData icon,
    required String text,
    IconData? dynamicIcon,
  }) {
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).buttonTheme.colorScheme?.primary),
                child: Icon(dynamicIcon ?? icon,
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
  void initState() {
    super.initState();
    dateRange = widget.startingDateRange;
    transactionType = widget.startingTransactionType;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = [];

    if (resultsAreFiltered()) {
      actions = [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
          child: IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                setState(() {
                  searchString = "";
                  dateRange = null;
                  typeIndex = 0;
                  selectedCategories = [];
                });
              }),
        )
      ];
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Transactions"), actions: actions),
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
                        condition: amountFilter != null,
                        onTap: () async {
                          AmountFilter? result =
                              await _showAmountFilterDialog();

                          setState(() => amountFilter = result);
                        },
                        icon: Icons.attach_money,
                        dynamicIcon: amountFilter == null
                            ? Icons.attach_money
                            : amountFilter!.type == AmountFilterType.exactly
                                ? Icons.balance
                                : amountFilter!.type ==
                                        AmountFilterType.lessThan
                                    ? Icons.chevron_left
                                    : Icons.chevron_right,
                        text: amountFilter == null
                            ? '0'
                            : amountFilter!.value.toString()),
                    _getButton(
                      icon: Icons.search,
                      text: searchString.isNotEmpty ? searchString : "Error",
                      condition: searchString.isNotEmpty,
                      onTap: () async {
                        String? result = await _showTextInputDialog("Search");

                        setState(() => searchString = result ?? "");
                      },
                    ), // Make search search
                    _getButton(
                      icon: Icons.category,
                      text: selectedCategories.isNotEmpty
                          ? selectedCategories.join(", ")
                          : "Error",
                      condition: selectedCategories.isNotEmpty,
                      onTap: () async {
                        List<String>? result = await _showCategoryInputDialog();

                        setState(() => selectedCategories = result ?? []);
                      },
                    ),
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
              dateRange: dateRange,
              type: transactionType,
              containsString: searchString,
              categories: selectedCategories,
            )),
          ],
        ),
      ),
    );
  }
}
