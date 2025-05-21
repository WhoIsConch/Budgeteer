import 'package:budget/models/database_extensions.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/appui/transactions/transactions_list.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TransactionSearch extends StatefulWidget {
  final List<TransactionFilter>? initialFilters;
  final Sort? initialSortType;

  const TransactionSearch({
    super.key,
    this.initialFilters,
    this.initialSortType,
  });

  @override
  State<TransactionSearch> createState() => _TransactionSearchState();
}

class _TransactionSearchState extends State<TransactionSearch> {
  // Making filters a Set ensures that all items are unique and there is not
  // a multiple of a filter in there
  bool isSearching = false; // Is the title bar a search field?
  TextEditingController searchController = TextEditingController();
  late TransactionProvider provider;

  Sort get sort => provider.sort;
  List<TransactionFilter> get filters => provider.filters;

  List<Widget> getFilterChips() {
    List<Widget> chips = [];
    DateFormat dateFormat = DateFormat('MM/dd');

    for (TransactionFilter filter in filters) {
      String label = switch (filter) {
        TransactionFilter<String> t => '"${t.value}"', // "Value"
        TransactionFilter<AmountFilter> t =>
          '${t.value.type!.symbol} \$${formatAmount(t.value.amount ?? 0, exact: true)}', // > $Value
        TransactionFilter<List<CategoryWithAmount>> t =>
          t.value.length > 3
              ? '${t.value.length} categories'
              : t.value.map((e) => e.category.name).join(', '),
        TransactionFilter<DateTimeRange> t =>
          '${dateFormat.format(t.value.start)}–${dateFormat.format(t.value.end)}',
        TransactionFilter<RelativeDateRange> t =>
          '${dateFormat.format(t.value.getRange().start)}–${dateFormat.format(t.value.getRange().end)}',
        TransactionFilter<TransactionType> t =>
          t.value == TransactionType.expense ? 'Expense' : 'Income',
        _ => 'ERR',
      };

      if (label.startsWith('ERR')) {
        AppLogger().logger.e(
          'Failed to filter transactions: Unexpected value:\n${filter.value}',
        );
      }

      chips.add(
        GestureDetector(
          onTap: () => _activateFilter(filter.value.runtimeType),
          child: Chip(
            label: Text(label),
            deleteIcon: const Icon(Icons.close),
            onDeleted: () {
              searchController.clear();
              provider.removeFilter(filterType: filter.value.runtimeType);
            },
          ),
        ),
      );
    }

    return chips;
  }

  Widget getTitle() {
    if (isSearching) {
      return TextField(
        controller: searchController,
        decoration: const InputDecoration(
          icon: Icon(Icons.search),
          hintText: 'Search',
        ),
      );
    }
    return const Text('Transactions');
  }

  Future<TransactionFilter?> _showAmountFilterDialog(
    BuildContext context,
  ) async {
    // Shows a dialog inline with a dropdown showing the filter type first,
    // then the amount as an input.
    TextEditingController controller = TextEditingController();
    // Either get the current amountFilter or create a new one
    AmountFilter amountFilter =
        provider.getFilterValue<AmountFilter>() ?? AmountFilter();
    // Update the text to match
    controller.text = amountFilter.amount?.toStringAsFixed(2) ?? '';

    // Listen for changes on the controller since it's easier and better-looking
    // than redoing it in the end, though probably less performant
    controller.addListener(
      () =>
          amountFilter = AmountFilter(
            type: amountFilter.type,
            amount: double.tryParse(controller.text) ?? amountFilter.amount,
          ),
    );

    return showDialog<TransactionFilter>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Filter by Amount'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton(
                    onSelectionChanged:
                        (type) => setState(() {
                          amountFilter = AmountFilter(
                            type: type.first,
                            amount: amountFilter.amount,
                          );
                        }),
                    showSelectedIcon: false,
                    selected: {amountFilter.type ?? AmountFilterType.exactly},
                    segments:
                        AmountFilterType.values
                            .map(
                              (value) => ButtonSegment(
                                value: value,
                                label: Text(
                                  toTitleCase(value.name),
                                  maxLines: 2,
                                ),
                              ),
                            )
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
                        hintText: 'Amount',
                        prefixText: '\$ ',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (double.tryParse(controller.text) == null) {
                      return Navigator.pop(context);
                    }

                    return Navigator.pop(
                      context,
                      TransactionFilter<AmountFilter>(amountFilter),
                    );
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

  Future<List<CategoryWithAmount>?> _showCategoryInputDialog(
    BuildContext context,
  ) async {
    // Shows a dropdown of all available categories.
    // Returns a list of selected categories.
    // This shows an AlertDialog with nothing in it other than a dropdown
    // which a user can select multiple categories from.
    final db = context.read<AppDatabase>();

    List<CategoryWithAmount> selectedCategories =
        provider.getFilterValue<List<CategoryWithAmount>>() ?? [];

    if (!context.mounted) {
      return [];
    }

    return showDialog<List<CategoryWithAmount>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              scrollable: true,
              title: const Text('Select Categories'),
              content: SizedBox(
                width: double.maxFinite,
                child: StreamBuilder<List<CategoryWithAmount>>(
                  initialData: const [],
                  stream: db.categoryDao.watchCategories(),
                  builder:
                      (context, snapshot) => ListView.builder(
                        shrinkWrap: true,
                        itemCount: snapshot.data!.length,
                        itemBuilder: (BuildContext context, int index) {
                          final pair = snapshot.data![index];

                          return CheckboxListTile(
                            title: Text(pair.category.name),
                            value:
                                selectedCategories
                                    .where(
                                      (e) => e.category.id == pair.category.id,
                                    )
                                    .isNotEmpty,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value != null) {
                                  if (value) {
                                    selectedCategories.add(pair);
                                  } else {
                                    selectedCategories.removeWhere(
                                      (e) => e.category.id == pair.category.id,
                                    );
                                  }
                                }
                              });
                            },
                          );
                        },
                      ),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => selectedCategories = []),
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(selectedCategories);
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void toggleTransactionType() {
    TransactionType? typeFilterValue =
        provider.getFilterValue<TransactionType>();
    TransactionFilter? filter;

    if (typeFilterValue == null || typeFilterValue == TransactionType.expense) {
      filter = const TransactionFilter<TransactionType>(TransactionType.income);
    } else if (typeFilterValue == TransactionType.income) {
      filter = const TransactionFilter<TransactionType>(
        TransactionType.expense,
      );
    }

    setState(() {
      if (filter == null) {
        provider.removeFilter<TransactionType>();
      } else {
        provider.updateFilter(filter);
      }
    });
  }

  List<Widget> get filterMenuButtons => [
    MenuItemButton(
      child: const Text('Date'),
      onPressed: () => _activateFilter(DateTimeRange),
    ),
    MenuItemButton(
      child: const Text('Amount'),
      onPressed: () => _activateFilter(AmountFilter),
    ),
    MenuItemButton(
      child: const Text('Type'),
      onPressed: () => _activateFilter(TransactionType),
    ),
    MenuItemButton(
      child: const Text('Category'),
      onPressed: () => _activateFilter(List<CategoryWithAmount>),
    ),
  ];

  List<Widget> get sortMenuButtons =>
      SortType.values
          .map(
            (type) => MenuItemButton(
              closeOnActivate: false,
              trailingIcon:
                  sort.sortType == type
                      ? switch (sort.sortOrder) {
                        SortOrder.ascending => const Icon(Icons.arrow_upward),
                        SortOrder.descending => const Icon(
                          Icons.arrow_downward,
                        ),
                      }
                      : null,
              onPressed: () {
                Sort newSort;

                if (sort.sortType == type) {
                  newSort = Sort(
                    type,
                    sort.sortOrder == SortOrder.descending
                        ? SortOrder.ascending
                        : SortOrder.descending,
                  );
                } else {
                  newSort = Sort(type, SortOrder.descending);
                }

                provider.update(sort: newSort);
              },
              child: Text(toTitleCase(type.name)),
            ),
          )
          .toList();

  List<Widget> get mainMenuButtons => [
    SubmenuButton(
      menuChildren: filterMenuButtons,
      child: const Text('Filter by'),
    ),
    SubmenuButton(menuChildren: sortMenuButtons, child: const Text('Sort by')),
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
              },
            ),
  );

  Map<Type, Function> get _filterActions => {
    DateTimeRange:
        () => showDateRangePicker(
          context: context,
          initialDateRange: provider.getFilterValue<DateTimeRange>(),
          firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        ).then((DateTimeRange? value) {
          if (value == null) return;

          provider.updateFilter(TransactionFilter<DateTimeRange>(value));
        }),
    String: () => setState(() => isSearching = true),
    AmountFilter:
        () => _showAmountFilterDialog(context).then((value) {
          if (value == null) {
            return;
          }
          provider.updateFilter(value as TransactionFilter<AmountFilter>);
        }),
    TransactionType: () => toggleTransactionType(),
    List<CategoryWithAmount>:
        () => _showCategoryInputDialog(context).then((value) {
          if (value == null) {
            return;
          } else if (value.isEmpty) {
            provider.removeFilter<List<CategoryWithAmount>>();
          } else {
            provider.updateFilter(
              TransactionFilter<List<CategoryWithAmount>>(value),
            );
          }
        }),
  };

  void _activateFilter(Type type) {
    final action = _filterActions[type];

    if (action != null) {
      action();
    } else {
      throw FilterTypeException(type);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('Dependencies');
    provider = context.watch<TransactionProvider>();
  }

  @override
  void dispose() async {
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
          },
        ),
        filterButton,
      ];
    } else {
      appBarActions = [
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: () {
            String text = searchController.text.trim();

            if (text.length > 30) {
              text = '${text.substring(0, 27)}...';
            }

            TransactionFilter<String> filter = TransactionFilter(text);

            if (filters.contains(filter) || filter.value.isEmpty) {
              // The list of filters already has the exact same filter,
              // so we don't do anything other than stop searching.
              setState(() => isSearching = false);
              return;
            }

            isSearching = false;
            provider.updateFilter(filter);
          },
        ),
      ];

      leading = IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => isSearching = false),
      );
    }

    body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Wrap(spacing: 4, children: getFilterChips()),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: TransactionsList(
              showBackground: false,
              showActionButton: true,
              filters: provider.filters,
              sort: provider.sort,
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: leading,
        titleSpacing: 0,
        title: getTitle(),
        actions: appBarActions,
      ),
      body: body,
    );
  }
}
