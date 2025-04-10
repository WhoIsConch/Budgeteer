import 'package:budget/components/transactions_list.dart';
import 'package:budget/tools/enums.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum TransactionFilterType { string, category, type, amount, dateRange }

enum TransactionSortType { name, date, amount }

class TransactionFilter {
  final TransactionFilterType filterType;
  final String name;
  final dynamic value;

  const TransactionFilter(this.filterType, this.name, this.value);

  @override
  bool operator ==(Object other) {
    return other is TransactionFilter &&
        filterType == other.filterType &&
        name == other.name &&
        value == other.value;
  }

  @override
  int get hashCode => Object.hash(filterType, name, value);
}

class TransactionSearch extends StatefulWidget {
  final Set<TransactionFilter>? initialFilters;
  final TransactionSortType? initialSortType;

  const TransactionSearch(
      {super.key, this.initialFilters, this.initialSortType});

  @override
  State<TransactionSearch> createState() => _TransactionSearchState();
}

class _TransactionSearchState extends State<TransactionSearch> {
  // Making filters a Set ensures that all items are unique and there is not
  // a multiple of a filter in there
  late Set<TransactionFilter> filters;
  TransactionSortType? sortType;
  bool isSearching = false; // Is the title bar a search field?
  TextEditingController searchController = TextEditingController();

  List<Widget> getFilterChips() {
    List<Widget> chips = [];
    DateFormat dateFormat = DateFormat('MM/dd/yyyy');

    for (TransactionFilter filter in filters) {
      String label = switch (filter.filterType) {
        TransactionFilterType.string => "\"${filter.value}\"", // "Value"
        TransactionFilterType.amount =>
          "${filter.name} \$${filter.value}", // > $Value
        TransactionFilterType.category => filter.value.length > 3
            ? "${filter.value.length} categories"
            : filter.value.join(", "),
        TransactionFilterType.dateRange =>
          "${dateFormat.format(filter.value.start)}-${dateFormat.format(filter.value.end)}",
        TransactionFilterType.type =>
          filter.value == TransactionType.expense ? "Expense" : "Income"
      };

      chips.add(Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close),
        onDeleted: () => setState(() {
          filters.remove(filter);
          searchController.clear();
        }),
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
        IconButton(icon: const Icon(Icons.tune), onPressed: () {})
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
                TransactionFilter(TransactionFilterType.string, "Text", text);

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
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: getFilterChips(),
            ),
          ),
          Expanded(child: TransactionsList())
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
