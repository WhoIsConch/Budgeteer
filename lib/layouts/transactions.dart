import 'package:budget/components/hybrid_button.dart';
import 'package:budget/components/transaction_form.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/validators.dart';
import 'package:flutter/material.dart';
import 'package:budget/components/transactions_list.dart';
import 'package:budget/tools/enums.dart';

String toTitleCase(String s) => s
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());

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
  List types = [null, ...TransactionType.values];
  List typesIcons = [
    const Icon(Icons.all_inclusive),
    const Icon(Icons.remove),
    const Icon(Icons.add)
  ];
  int typeIndex = 0;
  AmountFilter? amountFilter;

  String searchString = "";
  List<Category> allCategories = <Category>[];
  List<Category> selectedCategories = [];

  bool resultsAreFiltered() {
    return searchString.isNotEmpty ||
        dateRange != null ||
        allCategories.isNotEmpty ||
        typeIndex % 3 != 0 ||
        selectedCategories.isNotEmpty ||
        amountFilter != null;
  }

  TransactionType? get transactionType {
    return types[typeIndex % 3];
  }

  Future<List<Category>?> _showCategoryInputDialog(BuildContext context) async {
    // Shows a dropdown of all available categories.
    // Returns a list of selected categories.
    // This shows an AlertDialog with nothing in it other than a dropdown
    // which a user can select multiple categories from.

    List<Category> categories = await _dbHelper.getCategoriesList();

    if (!context.mounted) {
      return [];
    }

    return showDialog<List<Category>>(
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
                      title: Text(category.name),
                      value: selectedCategories
                          .where(
                            (e) => e.id == category.id,
                          )
                          .isNotEmpty,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value != null) {
                            if (value) {
                              selectedCategories.add(category);
                            } else {
                              selectedCategories
                                  .removeWhere((e) => e.id == category.id);
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

  Future<AmountFilter?> _showAmountFilterDialog(BuildContext context) async {
    // Shows a dialog inline with a dropdown showing the filter type first,
    // then the amount as an input.
    TextEditingController controller = TextEditingController();
    controller.text = amountFilter?.value.toString() ?? "";
    amountFilter = AmountFilter(type: AmountFilterType.exactly);

    return showDialog<AmountFilter>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
                title: const Text("Filter by Amount"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton(
                      onSelectionChanged: (type) => setState(() {
                        amountFilter = AmountFilter(type: type.first);
                      }),
                      showSelectedIcon: false,
                      selected: {
                        amountFilter?.type ?? AmountFilterType.exactly
                      },
                      segments: AmountFilterType.values
                          .map((value) => ButtonSegment(
                              value: value,
                              label: Text(
                                toTitleCase(value.name),
                                maxLines: 2,
                              )))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: TextField(
                          inputFormatters: [DecimalTextInputFormatter()],
                          keyboardType: TextInputType.number,
                          controller: controller,
                          decoration: const InputDecoration(
                              hintText: "Amount",
                              prefixText: "\$ ",
                              isDense: true)),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      if (double.tryParse(controller.text) == null) {
                        return Navigator.pop(context, null);
                      }

                      return Navigator.pop(
                          context,
                          AmountFilter(
                              type: amountFilter?.type,
                              value: double.parse(controller.text)));
                    },
                    child: const Text("OK"),
                  )
                ]);
          });
        });
  }

  Future<String?> _showTextInputDialog(
      BuildContext context, String title) async {
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

  @override
  void initState() {
    super.initState();
    dateRange = widget.startingDateRange;

    for (int i = 0; i < types.length; i++) {
      if (widget.startingTransactionType == types[i]) {
        typeIndex = i;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = [
      IconButton(
        icon: const Icon(Icons.add),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    const TransactionManageScreen(mode: ObjectManageMode.add))),
      )
    ];

    // Purposely swap out the plus button
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
                  amountFilter = null;
                });
              }),
        )
      ];
    }

    List<HybridButton> topRow = [
      HybridButton(
          buttonType: HybridButtonType.input,
          preference: 5,
          icon: const Icon(Icons.date_range),
          text: dateRange != null
              ? "${dateRange!.start.month}/${dateRange!.start.day}/${dateRange!.start.year} - ${dateRange!.end.month}/${dateRange!.end.day}/${dateRange!.end.year}"
              : "All Time",
          isEnabled: dateRange != null,
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
          }),
      HybridButton(
        preference: 4,
        buttonType: HybridButtonType.input,
        isEnabled: amountFilter != null,
        onTap: () async {
          AmountFilter? result = await _showAmountFilterDialog(context);

          setState(() => amountFilter = result);
        },
        icon: const Icon(Icons.attach_money),
        text:
            amountFilter == null ? '0' : "\$${amountFilter!.value.toString()}",
        dynamicIconSelector: () => switch (amountFilter?.type) {
          AmountFilterType.greaterThan => const Icon(Icons.chevron_right),
          AmountFilterType.lessThan => const Icon(Icons.chevron_left),
          _ => const Icon(Icons.balance),
        },
      ),
      HybridButton(
        preference: 3,
        buttonType: HybridButtonType.input,
        onTap: () async {
          String? result = await _showTextInputDialog(context, "Search");

          setState(() => searchString = result ?? "");
        },
        icon: const Icon(Icons.search),
        isEnabled: searchString.isNotEmpty,
        text: searchString.isNotEmpty ? searchString : "Error",
      ),
      HybridButton(
          preference: 2,
          buttonType: HybridButtonType.input,
          icon: const Icon(Icons.category),
          text: selectedCategories.isNotEmpty
              ? selectedCategories
                  .map(
                    (e) => e.name,
                  )
                  .toList()
                  .join(", ")
              : "Error",
          isEnabled: selectedCategories.isNotEmpty,
          onTap: () async {
            List<Category>? result = await _showCategoryInputDialog(context);

            setState(() => selectedCategories = result ?? []);
          }),
      HybridButton(
          preference: 1,
          isEnabled: typeIndex % 3 != 0,
          buttonType: HybridButtonType.toggle,
          icon: typesIcons[typeIndex % 3],
          onTap: () => setState(() {
                typeIndex += 1;
              })),
    ];

    topRow.sort((a, b) {
      if (a.isEnabled && b.isEnabled) {
        return b.preference.compareTo(a.preference);
      }

      return a.isEnabled ? -1 : 1;
    });

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
                  children: topRow,
                ),
              ),
            ),
            Expanded(
                child: TransactionsList(
              dateRange: dateRange,
              type: transactionType,
              searchString: searchString,
              searchCategories: selectedCategories,
              amountFilter: amountFilter,
              showActionButton: false,
            )),
          ],
        ),
      ),
    );
  }
}
