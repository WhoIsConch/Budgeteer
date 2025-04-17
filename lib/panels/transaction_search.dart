import 'package:budget/components/transactions_list.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/filters.dart';
import 'package:budget/tools/validators.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TransactionSearch extends StatefulWidget {
  final Set<TransactionFilter>? initialFilters;
  final Sort? initialSortType;

  const TransactionSearch(
      {super.key, this.initialFilters, this.initialSortType});

  @override
  State<TransactionSearch> createState() => _TransactionSearchState();
}

class _TransactionSearchState extends State<TransactionSearch> {
  // Making filters a Set ensures that all items are unique and there is not
  // a multiple of a filter in there
  late Set<TransactionFilter> filters;
  late Sort sort;
  bool isSearching = false; // Is the title bar a search field?
  TextEditingController searchController = TextEditingController();

  List<Widget> getFilterChips() {
    List<Widget> chips = [];
    DateFormat dateFormat = DateFormat('MM/dd');

    for (TransactionFilter filter in filters) {
      var value = filter.value;

      String label = switch (value.type) {
        String => "\"$value\"", // "Value"
        AmountFilter =>
          "${value.type.symbol} \$${formatAmount(value.amount, exact: true)}",
        List<Category>() => value.length > 3
            ? "${value.length} categories"
            : value.map((e) => e.name).join(", "),
        DateTimeRange =>
          "${dateFormat.format(value.start)}–${dateFormat.format(value.end)}",
        TransactionType =>
          value == TransactionType.expense ? "Expense" : "Income",
        _ => "Err"
      };

      chips.add(GestureDetector(
        onTap: () => _activateFilter(filter),
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
    AmountFilter amountFilter =
        getFilterValue<AmountFilter>(filters.toList()) ??
            const AmountFilter(AmountFilterType.exactly, 0);
    // Update the text to match
    controller.text = amountFilter.value.toStringAsFixed(2);

    // Listen for changes on the controller since it's easier and better-looking
    // than redoing it in the end, though probably less performant
    controller.addListener(() => amountFilter = AmountFilter(
        AmountFilterType.exactly,
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
                        amountFilter =
                            AmountFilter(type.first, amountFilter.value);
                      }),
                      showSelectedIcon: false,
                      selected: {amountFilter.type},
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

  Future<List<Category>?> _showCategoryInputDialog(BuildContext context) async {
    // Shows a dropdown of all available categories.
    // Returns a list of selected categories.
    // This shows an AlertDialog with nothing in it other than a dropdown
    // which a user can select multiple categories from.
    final provider = Provider.of<TransactionProvider>(context, listen: false);

    List<Category> categories = provider.categories;
    List<Category> selectedCategories =
        getFilterValue<List<Category>>(filters.toList()) ?? [];

    if (!context.mounted) {
      return [];
    }

    return showDialog<List<Category>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              scrollable: true,
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
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () =>
                            setState(() => selectedCategories = []),
                        child: Text("Clear",
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(selectedCategories);
                        },
                        child: const Text('OK'),
                      ),
                    ])
              ],
            );
          },
        );
      },
    );
  }

  void toggleTransactionType() {
    TransactionType? type = getFilterValue<TransactionType>(filters.toList());

    if (type == null) {
      type = TransactionType.expense;
    } else if (type == TransactionType.expense) {
      type = TransactionType.income;
    } else {
      type = null;
    }

    setState(() {
      if (type == null) {
        removeFilter<TransactionType>(filters.toList());
      } else {
        updateFilter(
            filters.toList(), TransactionFilter<TransactionType>(type));
      }
    });
  }

  List<Widget> get filterMenuButtons => [
        MenuItemButton(
          child: const Text("Date"),
          onPressed: () => _activateFilter<DateTimeRange>(
              getFilter<DateTimeRange>(filters.toList()) ??
                  TransactionFilter<DateTimeRange>(DateTimeRange(
                      start: DateTime.now(), end: DateTime.now()))),
        ),
        MenuItemButton(
          child: const Text("Amount"),
          onPressed: () => _activateFilter(
              getFilter<AmountFilter>(filters.toList()) ??
                  const TransactionFilter<AmountFilter>(
                      AmountFilter(AmountFilterType.exactly, 0))),
        ),
        MenuItemButton(
          child: const Text("Type"),
          onPressed: () => _activateFilter(getFilter<TransactionType>(filters.toList()) ?? const TransactionFilter<TransactionType>)),
        ),
        MenuItemButton(
          child: const Text("Category"),
          onPressed: () => _activateFilter(List<Category>),
        ),
      ];

  List<Widget> get sortMenuButtons => SortType.values
      .map((type) => MenuItemButton(
          closeOnActivate: false,
          trailingIcon: sort.sortType == type
              ? switch (sort.sortOrder) {
                  SortOrder.ascending => const Icon(Icons.arrow_upward),
                  SortOrder.descending => const Icon(Icons.arrow_downward)
                }
              : null,
          onPressed: () {
            if (sort.sortType == type) {
              sort = Sort(
                  type,
                  sort.sortOrder == SortOrder.descending
                      ? SortOrder.ascending
                      : SortOrder.descending);
            } else {
              sort = Sort(
                type,
                SortOrder.descending,
              );
            }

            setState(() => sort = sort);
          },
          child: Text(toTitleCase(type.name))))
      .toList();

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

  void _activateFilter<T>(TransactionFilter<T> filter) => switch (filter) {
        TransactionFilter<DateTimeRange> f => showDateRangePicker(
                  context: context,
                  initialDateRange: f.value, // Should be null or a date range
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 365 * 10)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)))
              .then((DateTimeRange? newValue) {
            if (newValue == f.value || newValue == null) return;

            setState(() {
              updateFilter(filters.toList(),
                  TransactionFilter<DateTimeRange>(newValue.makeInclusive()));
            });
          }),
        TransactionFilter<String> _ => setState(() => isSearching = true),
        TransactionFilter<AmountFilter> _ =>
          _showAmountFilterDialog(context).then((value) {
            if (value == null) {
              return;
            }
            setState(() {
              updateFilter(filters.toList(), value);
            });
          }),
        TransactionFilter<TransactionType> _ => toggleTransactionType(),
        TransactionFilter<List<Category>> _ =>
          _showCategoryInputDialog(context).then((value) {
            if (value == null) {
              return;
            } else if (value.isEmpty) {
              setState(
                () => removeFilter<List<Category>>(filters.toList()),
              );
            } else {
              // TODO: Make sure this works correctly. I wonder if we need to
              // specify the generic type in both the TransactionFilter and
              // the function call, or if just knowing what type the filter
              // holds is enough and the updateFilter specification would be
              // unnecessary
              setState(() => updateFilter(
                  filters.toList(), TransactionFilter<List<Category>>(value)));
            }
          }),
        _ => throw Error()
      };

  @override
  void initState() {
    super.initState();

    // Initialize these filters to easily use and edit inside of the menus
    filters = widget.initialFilters ?? {};
    sort = widget.initialSortType ??
        const Sort(SortType.date, SortOrder.descending);
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

            TransactionFilter<String> filter = TransactionFilter<String>(text);

            if (filters.contains(filter) || filter.value.isEmpty) {
              // The list of filters already has the exact same filter,
              // so we don't do anything other than stop searching.
              setState(() => isSearching = false);
              return;
            }

            setState(() {
              isSearching = false;

              updateFilter<String>(filters.toList(), filter);
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
          Expanded(
              child: TransactionsList(
            filters: filters,
            sort: sort,
          ))
        ],
      );
    } else {
      body = TransactionsList(
        sort: sort,
      );
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
