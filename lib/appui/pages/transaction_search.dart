import 'package:budget/models/database_extensions.dart';
import 'package:budget/appui/components/objects_list.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TransactionSearchPage extends StatelessWidget {
  final Set<Filter>? initialFilters;
  final Sort? initialSortType;

  const TransactionSearchPage({
    super.key,
    this.initialFilters,
    this.initialSortType,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) =>
              TransactionProvider()..update(
                filters: initialFilters?.toList(),
                sort: initialSortType,
                notify: false,
              ),
      child: TransactionSearch(
        initialFilters: initialFilters,
        initialSortType: initialSortType,
      ),
    );
  }
}

class TransactionSearch extends StatefulWidget {
  final Set<Filter>? initialFilters;
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

  List<Widget> getFilterChips() {
    List<Widget> chips = [];
    DateFormat dateFormat = DateFormat('MM/dd');
    final provider = context.watch<TransactionProvider>();

    for (Filter filter in provider.filters) {
      String label = switch (filter) {
        TextFilter t => '"${t.text}"', // "Value"
        AmountFilter t =>
          '${t.type.symbol} \$${formatAmount(t.amount, exact: true)}', // > $Value
        CategoryFilter t =>
          t.categories.length > 3
              ? '${t.categories.length} categories'
              : t.categories.map((e) => e.category.name).join(', '),
        AccountFilter t =>
          t.accounts.length > 3
              ? '${t.accounts.length} accounts'
              : t.accounts.map((e) => e.account.name).join(', '),
        GoalFilter t =>
          t.goals.length > 3
              ? '${t.goals.length} goals'
              : t.goals.map((e) => e.goal.name).join(', '),
        DateRangeFilter t =>
          '${dateFormat.format(t.dateRange.start)}–${dateFormat.format(t.dateRange.end)}',
        TypeFilter t =>
          t.type == TransactionType.expense ? 'Expense' : 'Income',
      };

      chips.add(
        GestureDetector(
          onTap: () => _activateFilter(context, filter: filter),
          child: Chip(
            label: Text(label),
            deleteIcon: const Icon(Icons.close),
            onDeleted: () {
              searchController.clear();
              provider.removeFilter(filterType: filter.runtimeType);
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

  Future<AmountFilter?> _showAmountFilterDialog() async {
    final provider = context.read<TransactionProvider>();
    // Shows a dialog inline with a dropdown showing the filter type first,
    // then the amount as an input.
    TextEditingController controller = TextEditingController();
    // Either get the current amountFilter or create a new one
    AmountFilter? amountFilter = provider.getFilter<AmountFilter>();
    // Update the text to match
    controller.text = amountFilter?.amount.toStringAsFixed(2) ?? '';

    // Listen for changes on the controller since it's easier and better-looking
    // than redoing it in the end, though probably less performant
    controller.addListener(() {
      final amount = double.tryParse(controller.text) ?? amountFilter?.amount;

      if (amountFilter?.type == null || amount == null) {
        return;
      }

      amountFilter = AmountFilter(amountFilter!.type, amount);
    });

    return showDialog<AmountFilter>(
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
                            type.first,
                            amountFilter?.amount ?? 0,
                          );
                        }),
                    showSelectedIcon: false,
                    selected: {amountFilter?.type ?? AmountFilterType.exactly},
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

                    return Navigator.pop(context, amountFilter);
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

  Future<List<CategoryWithAmount>?> _showCategoryInputDialog() async {
    // Shows a dropdown of all available categories.
    // Returns a list of selected categories.
    // This shows an AlertDialog with nothing in it other than a dropdown
    // which a user can select multiple categories from.
    final db = context.read<AppDatabase>();
    final provider = context.read<TransactionProvider>();

    List<CategoryWithAmount> selectedCategories =
        provider.getFilter<CategoryFilter>()?.categories ?? [];

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

  void toggleTransactionType(BuildContext context) {
    final provider = context.read<TransactionProvider>();

    TransactionType? typeFilterValue = provider.getFilter<TypeFilter>()?.type;
    TypeFilter? filter;

    if (typeFilterValue == null || typeFilterValue == TransactionType.expense) {
      filter = TypeFilter(TransactionType.income);
    } else if (typeFilterValue == TransactionType.income) {
      filter = TypeFilter(TransactionType.expense);
    }

    if (filter == null) {
      provider.removeFilter<TypeFilter>();
    } else {
      provider.updateFilter<TypeFilter>(filter);
    }
  }

  List<Widget> _getFilterMenuButtons(BuildContext context) {
    final widgetContext = context;

    return [
      MenuItemButton(
        child: const Text('Date'),
        onPressed: () => _activateFilter<DateRangeFilter>(widgetContext),
      ),
      MenuItemButton(
        child: const Text('Amount'),
        onPressed: () => _activateFilter<AmountFilter>(widgetContext),
      ),
      MenuItemButton(
        child: const Text('Type'),
        onPressed: () => _activateFilter<TypeFilter>(widgetContext),
      ),
      StreamBuilder(
        stream: context.read<AppDatabase>().categoryDao.watchCategoryCount(),
        builder: (streamContext, snapshot) {
          final hasCategories = snapshot.hasData && snapshot.data! > 0;

          return MenuItemButton(
            onPressed:
                hasCategories
                    ? () => _activateFilter<CategoryFilter>(widgetContext)
                    : null,

            child: Text(
              'Category',
              style:
                  hasCategories
                      ? null
                      : TextStyle(color: Theme.of(streamContext).disabledColor),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _getSortMenuButtons(BuildContext context) {
    final provider = context.read<TransactionProvider>();

    return SortType.values
        .map(
          (type) => MenuItemButton(
            closeOnActivate: false,
            trailingIcon:
                provider.sort.sortType == type
                    ? switch (provider.sort.sortOrder) {
                      SortOrder.ascending => const Icon(Icons.arrow_upward),
                      SortOrder.descending => const Icon(Icons.arrow_downward),
                    }
                    : null,
            onPressed: () {
              Sort newSort;

              if (provider.sort.sortType == type) {
                newSort = Sort(
                  type,
                  provider.sort.sortOrder == SortOrder.descending
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
  }

  List<Widget> _getMainMenuButtons(BuildContext context) => [
    SubmenuButton(
      menuChildren: _getFilterMenuButtons(context),
      child: const Text('Filter by'),
    ),
    SubmenuButton(
      menuChildren: _getSortMenuButtons(context),
      child: const Text('Sort by'),
    ),
  ];

  Widget filterButton(BuildContext context) => MenuAnchor(
    alignmentOffset: const Offset(-40, 0),
    menuChildren: _getMainMenuButtons(context),
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

  Map<Type, Function> _getFilterActions(TransactionProvider provider) {
    return {
      DateRangeFilter:
          () => showDateRangePicker(
            context: context,
            initialDateRange: provider.getFilter<DateRangeFilter>()?.dateRange,
            firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
            lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
          ).then((DateTimeRange? value) {
            if (value == null) return;

            provider.updateFilter(DateRangeFilter(value));
          }),
      TextFilter: () => setState(() => isSearching = true),
      AmountFilter:
          () => _showAmountFilterDialog().then((value) {
            if (value == null) {
              return;
            }
            provider.updateFilter<AmountFilter>(value);
          }),
      TypeFilter: () => toggleTransactionType(context),
      CategoryFilter:
          () => _showCategoryInputDialog().then((value) {
            if (value == null) {
              return;
            } else if (value.isEmpty) {
              provider.removeFilter<CategoryFilter>();
            } else {
              provider.updateFilter(CategoryFilter(value));
            }
          }),
    };
  }

  void _activateFilter<F extends Filter>(BuildContext context, {F? filter}) {
    Function? filterAction;
    final provider = context.read<TransactionProvider>();

    if (filter != null) {
      filterAction = _getFilterActions(provider)[filter.runtimeType];
    } else {
      filterAction = _getFilterActions(provider)[F];
    }

    if (filterAction != null) {
      filterAction();
    } else {
      throw FilterTypeException(F);
    }
  }

  @override
  void dispose() async {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
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
            filterButton(context),
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

                TextFilter filter = TextFilter(text);

                if (provider.filters.contains(filter) || filter.text.isEmpty) {
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
            if (provider.filters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 4, children: getFilterChips()),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: ObjectsList<TransactionTileableAdapter>(
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
      },
    );
  }
}
