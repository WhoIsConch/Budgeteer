import 'package:budget/models/database_extensions.dart';
import 'package:budget/appui/components/objects_list.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/enums.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/services/providers/transaction_provider.dart';
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
  List<FilterChip> activeChips = [];

  List<Widget> getFilterChips() {
    DateFormat dateFormat = DateFormat('MM/dd');
    final provider = context.watch<TransactionProvider>();

    for (Filter filter in provider.filters) {
      String? label = switch (filter) {
        TextFilter t => '"${t.text}"', // "Value"
        AmountFilter t =>
          '${t.type.symbol} \$${formatAmount(t.amount, exact: true)}', // > $Value
        ContainerFilter t =>
          (() {
            if (t.itemIds == null) return null;

            if (t.itemIds!.length > 3) {
              return switch (t) {
                CategoryFilter f => '${f.categories!.length} categories',
                AccountFilter f => '${f.accounts!.length} accounts',
                GoalFilter f => '${f.goals!.length} goals',
              };
            }

            return switch (t) {
              CategoryFilter f => f.categories!
                  .map((e) => e.category.name)
                  .join(', '),
              AccountFilter f => f.accounts!
                  .map((e) => e.account.name)
                  .join(', '),
              GoalFilter f => f.goals!.map((e) => e.goal.name).join(', '),
            };
          })(),
        DateRangeFilter t =>
          '${dateFormat.format(t.dateRange.start)}–${dateFormat.format(t.dateRange.end)}',
        TypeFilter t =>
          t.type == TransactionType.expense ? 'Expense' : 'Income',
        _ => null,
      };

      if (label == null) continue;

      final index = activeChips.indexWhere((chip) => chip.filter == filter);
      final chip = FilterChip(
        key: ObjectKey(filter),
        filter: filter,
        label: label,
        onImmediateDeleted: (FilterChip chip) {
          searchController.clear();
          provider.removeFilter(filterType: filter.runtimeType);
        },
        onDeleted: (FilterChip chip) {
          setState(() => activeChips.remove(chip));
        },
        activateFilter: () => _performFilterAction(filter),
      );

      if (index == -1) {
        activeChips.add(chip);
      } else {
        activeChips.removeAt(index);
        activeChips.insert(index, chip);
      }
    }

    return activeChips;
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

  Future<void> _performAmountFilter({AmountFilter? existing}) async {
    final provider = context.read<TransactionProvider>();
    // Shows a dialog inline with a dropdown showing the filter type first,
    // then the amount as an input.
    TextEditingController controller = TextEditingController();

    AmountFilter? amountFilter = existing ?? provider.getFilter<AmountFilter>();

    // Update the text to match
    controller.text = existing?.amount.toStringAsFixed(2) ?? '';

    // Listen for changes on the controller since it's easier and better-looking
    // than redoing it in the end, though probably less performant
    controller.addListener(() {
      final amount = double.tryParse(controller.text) ?? amountFilter?.amount;

      if (amount == null) {
        return;
      }

      amountFilter = AmountFilter(
        amountFilter?.type ?? AmountFilterType.exactly,
        amount,
      );
    });

    final newFilter = await showDialog<AmountFilter>(
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

    if (newFilter != null) {
      provider.updateFilter<AmountFilter>(newFilter);
    }
  }

  Future<void> _performCategoryFilter({CategoryFilter? existing}) async {
    // Shows a dropdown of all available categories.
    // Returns a list of selected categories.
    // This shows an AlertDialog with nothing in it other than a dropdown
    // which a user can select multiple categories from.
    final db = context.read<AppDatabase>();
    final provider = context.read<TransactionProvider>();

    List<CategoryWithAmount> selectedCategories =
        existing?.categories ??
        provider.getFilter<CategoryFilter>()?.categories ??
        [];

    if (!context.mounted) {
      return;
    }

    final categories = await showDialog<List<CategoryWithAmount>>(
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

    if (categories == null) return;

    if (categories.isEmpty) {
      provider.removeFilter<CategoryFilter>();
    } else {
      provider.updateFilter<CategoryFilter>(CategoryFilter(categories));
    }
  }

  Future<void> _performDateRangeFilter({DateRangeFilter? existing}) async {
    final provider = context.read<TransactionProvider>();

    final initial =
        existing?.dateRange ?? provider.getFilter<DateRangeFilter>()?.dateRange;

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null) {
      provider.updateFilter<DateRangeFilter>(DateRangeFilter(picked));
    }
  }

  Future<void> _performFutureFilter({FutureFilter? existing}) async {
    final provider = context.read<TransactionProvider>();

    final initial = existing ?? provider.getFilter<FutureFilter>();

    if (initial?.includeFuture == true) {
      provider.updateFilter(FutureFilter(false));
    } else {
      provider.updateFilter(FutureFilter(true));
    }
  }

  Future<void> _performArchivedFilter({ArchivedFilter? existing}) async {
    final provider = context.read<TransactionProvider>();

    final initial = existing ?? provider.getFilter<ArchivedFilter>();

    if (initial?.isArchived == false) {
      provider.removeFilter<ArchivedFilter>();
    } else {
      provider.updateFilter(ArchivedFilter(false));
    }
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
    return [
      MenuItemButton(
        onPressed: _performDateRangeFilter, // Currently, there's no .empty
        child: const Text('Date'),
      ),
      MenuItemButton(
        onPressed: _performAmountFilter,
        child: const Text('Amount'),
      ),
      MenuItemButton(
        onPressed: () => toggleTransactionType(context),
        child: const Text('Type'),
      ),
      StreamBuilder(
        stream: context.read<AppDatabase>().categoryDao.watchCategoryCount(),
        builder: (streamContext, snapshot) {
          final hasCategories = snapshot.hasData && snapshot.data! > 0;

          return MenuItemButton(
            onPressed: hasCategories ? _performCategoryFilter : null,

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

  List<Widget> _getIncludeMenuButtons(BuildContext context) {
    final provider = context.read<TransactionProvider>();

    final showArchived = provider.getFilter<ArchivedFilter>()?.isArchived;
    final showFuture = provider.getFilter<FutureFilter>()?.includeFuture;

    return [
      MenuItemButton(
        trailingIcon:
            showArchived == null || showArchived ? Icon(Icons.check) : null,
        onPressed: _performArchivedFilter,
        child: Text('Archived'),
      ),
      MenuItemButton(
        trailingIcon: showFuture == true ? Icon(Icons.check) : null,
        onPressed: () => _performFutureFilter,
        child: Text('Future'),
      ),
    ];
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
    SubmenuButton(
      menuChildren: _getIncludeMenuButtons(context),
      child: const Text('Include...'),
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

  void _performFilterAction(Filter filter) {
    switch (filter) {
      case DateRangeFilter f:
        _performDateRangeFilter(existing: f);
        break;
      case TextFilter _:
        setState(() => isSearching = true);
        break;
      case AmountFilter f:
        _performAmountFilter(existing: f);
        break;
      case TypeFilter _:
        toggleTransactionType(context);
        break;
      case CategoryFilter f:
        _performCategoryFilter(existing: f);
        break;
      case ArchivedFilter f:
        _performArchivedFilter(existing: f);
        break;
      case FutureFilter f:
        _performFutureFilter(existing: f);
        break;

      default:
        break;
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

class FilterChip extends StatefulWidget {
  final String label;
  final Filter filter;
  final Function() activateFilter;
  final Function(FilterChip chip) onDeleted;
  final Function(FilterChip chip) onImmediateDeleted;

  const FilterChip({
    super.key,
    required this.filter,
    required this.label,
    required this.onDeleted,
    required this.onImmediateDeleted,
    required this.activateFilter,
  });

  @override
  State<FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<FilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDelete() {
    widget.onImmediateDeleted(widget);
    _controller.forward().whenComplete(() => widget.onDeleted(widget));
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _animation,
      axis: Axis.horizontal,
      axisAlignment: -1.0, // Starts shrinking at the start of the chip
      child: FadeTransition(
        opacity: _animation,
        child: GestureDetector(
          onTap: () {
            if (_animation.isAnimating) return;
            widget.activateFilter();
          },
          child: Chip(
            label: Text(widget.label),
            deleteIcon: const Icon(Icons.close),
            onDeleted: _handleDelete,
          ),
        ),
      ),
    );
  }
}
