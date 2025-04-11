import 'package:budget/components/transactions_list.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/validators.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum FilterType { string, category, type, amount, dateRange }

enum SortType { name, date, amount }

enum AmountFilterType { exactly, lessThan, greaterThan }

class TransactionFilter {
  final FilterType filterType;
  final dynamic info;
  final dynamic value;

  const TransactionFilter(this.filterType, this.info, this.value);

  @override
  bool operator ==(Object other) {
    return other is TransactionFilter &&
        filterType == other.filterType &&
        info == other.info &&
        value == other.value;
  }

  @override
  int get hashCode => Object.hash(filterType, info, value);
}

class TransactionSearch extends StatefulWidget {
  final Set<TransactionFilter>? initialFilters;
  final SortType? initialSortType;

  const TransactionSearch(
      {super.key, this.initialFilters, this.initialSortType});

  @override
  State<TransactionSearch> createState() => _TransactionSearchState();
}

class _TransactionSearchState extends State<TransactionSearch> {
  // Making filters a Set ensures that all items are unique and there is not
  // a multiple of a filter in there
  late Set<TransactionFilter> filters;
  SortType? sortType;
  bool isSearching = false; // Is the title bar a search field?
  TextEditingController searchController = TextEditingController();

  dynamic getFilterValue(FilterType filterType) {
    try {
      return filters.singleWhere((e) => e.filterType == filterType).value;
    } on StateError {
      return null;
    }
  }

  List<Widget> getFilterChips() {
    List<Widget> chips = [];
    DateFormat dateFormat = DateFormat('MM/dd');

    for (TransactionFilter filter in filters) {
      String label = switch (filter.filterType) {
        FilterType.string => "\"${filter.value}\"", // "Value"
        FilterType.amount => "${switch (filter.info as AmountFilterType) {
            AmountFilterType.exactly => "=",
            AmountFilterType.lessThan => "<",
            AmountFilterType.greaterThan => ">"
          }} \$${formatAmount(filter.value, exact: true)}", // > $Value
        FilterType.category => filter.value.length > 3
            ? "${filter.value.length} categories"
            : filter.value.join(", "),
        FilterType.dateRange =>
          "${dateFormat.format(filter.value.start)}–${dateFormat.format(filter.value.end)}",
        FilterType.type =>
          filter.value == TransactionType.expense ? "Expense" : "Income"
      };

      chips.add(GestureDetector(
        onTap: () => _activateFilter(filter.filterType),
        child: Chip(
          label: Text(label),
          deleteIcon: const Icon(Icons.close),
          onDeleted: () => setState(() {
            filters.remove(filter);
            searchController.clear();
          }),
        ),
      ));
    }

    return chips;
  }

  Widget getTitle() {
    if (isSearching) {
      return TextField(
        controller: searchController,
        decoration:
            const InputDecoration(icon: Icon(Icons.search), hintText: "Search"),
      );
    }
    return const Text("Transactions");
  }

  Future<TransactionFilter?> _showAmountFilterDialog(
      BuildContext context) async {
    // Shows a dialog inline with a dropdown showing the filter type first,
    // then the amount as an input.
    TextEditingController controller = TextEditingController();
    // Either get the current amountFilter or create a new one
    TransactionFilter amountFilter = filters.firstWhere(
        (e) => e.filterType == FilterType.amount,
        orElse: () => const TransactionFilter(
            FilterType.amount, AmountFilterType.exactly, null));
    // Update the text to match
    controller.text = amountFilter.value?.toStringAsFixed(2) ?? "";

    // Listen for changes on the controller since it's easier and better-looking
    // than redoing it in the end, though probably less performant
    controller.addListener(() => amountFilter = TransactionFilter(
        FilterType.amount,
        amountFilter.info,
        double.tryParse(controller.text) ?? amountFilter.value));

    return showDialog<TransactionFilter>(
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
                        amountFilter = TransactionFilter(
                            FilterType.amount, type.first, amountFilter.value);
                      }),
                      showSelectedIcon: false,
                      selected: {amountFilter.info ?? AmountFilterType.exactly},
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
                        return Navigator.pop(context);
                      }

                      return Navigator.pop(context, amountFilter);
                    },
                    child: const Text("OK"),
                  )
                ]);
          });
        });
  }

  List<Widget> get filterMenuButtons => [
        MenuItemButton(
          child: const Text("Date"),
          onPressed: () => _activateFilter(FilterType.dateRange),
        ),
        MenuItemButton(
          child: const Text("Amount"),
          onPressed: () => _activateFilter(FilterType.amount),
        ),
        MenuItemButton(
          child: const Text("Type"),
          onPressed: () {},
        ),
        MenuItemButton(
          child: const Text("Category"),
          onPressed: () {},
        ),
      ];

  List<Widget> get sortMenuButtons => const [
        MenuItemButton(
          child: Text("Name"),
        ),
        MenuItemButton(
          child: Text("Date"),
        ),
        MenuItemButton(
          child: Text("Amount"),
        ),
      ];

  List<Widget> get mainMenuButtons => [
        SubmenuButton(
          menuChildren: filterMenuButtons,
          child: const Text("Filter by"),
        ),
        SubmenuButton(
          menuChildren: sortMenuButtons,
          child: const Text("Sort by"),
        ),
      ];

  Widget get filterButton => MenuAnchor(
        alignmentOffset: const Offset(-40, 0),
        menuChildren: mainMenuButtons,
        builder:
            (BuildContext context, MenuController controller, Widget? child) =>
                IconButton(
                    icon: const Icon(Icons.tune),
                    onPressed: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    }),
      );

  void _activateFilter(FilterType filterType) => switch (filterType) {
        FilterType.dateRange => showDateRangePicker(
                  context: context,
                  initialDateRange: getFilterValue(
                      filterType), // Should be null or a date range
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365 * 10)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)))
              .then((DateTimeRange? value) {
            if (value == getFilterValue(filterType) || value == null) return;

            setState(() {
              filters.removeWhere((e) => e.filterType == filterType);
              filters.add(TransactionFilter(
                  FilterType.dateRange, "Date", value.makeInclusive()));
            });
          }),
        FilterType.string => setState(() => isSearching = true),
        FilterType.amount => _showAmountFilterDialog(context).then((value) {
            if (value == null) {
              return;
            }
            setState(() {
              filters.removeWhere((e) => e.filterType == filterType);
              filters.add(value);
            });
          }),
        _ => {}
      };

  @override
  void initState() {
    super.initState();

    // Initialize these filters to easily use and edit inside of the menus
    filters = widget.initialFilters ?? {};
    sortType = widget.initialSortType;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> appBarActions = [];
    Widget body;
    Widget? leading;

    if (!isSearching) {
      appBarActions = [
        IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() => isSearching = true);
            }),
        filterButton,
      ];
    } else {
      appBarActions = [
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: () {
            String text = searchController.text.trim();

            if (text.length > 30) {
              text = "${text.substring(0, 27)}...";
            }

            TransactionFilter filter =
                TransactionFilter(FilterType.string, "Text", text);

            if (filters.contains(filter) || filter.value.isEmpty) {
              // The list of filters already has the exact same filter,
              // so we don't do anything other than stop searching.
              setState(() => isSearching = false);
              return;
            }

            setState(() {
              isSearching = false;
              filters.removeWhere((e) => e.filterType == filter.filterType);
              filters.add(filter);
            });
          },
        )
      ];

      leading = IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => isSearching = false),
      );
    }

    if (filters.isNotEmpty) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Wrap(
              spacing: 4,
              children: getFilterChips(),
            ),
          ),
          const Expanded(child: TransactionsList())
        ],
      );
    } else {
      body = TransactionsList();
    }

    return Scaffold(
        appBar: AppBar(
          leading: leading,
          titleSpacing: 0,
          title: getTitle(),
          actions: appBarActions,
        ),
        body: body);
  }
}
