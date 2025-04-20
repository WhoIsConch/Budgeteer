import 'package:budget/tools/filters.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

class TransactionProvider extends ChangeNotifier {
  // Allows the rest of the app to know when transaction filters
  // change
  List<TransactionFilter> _filters = [];
  Sort _sort = const Sort(SortType.date, SortOrder.descending);

  List<TransactionFilter> get filters => _filters;
  Sort get sort => _sort;

  void update({List<TransactionFilter>? filters, Sort? sort}) {
    bool hasFiltersChanged = filters != null && filters != _filters;
    bool hasSortChanged = sort != null && sort != _sort;

    if (hasFiltersChanged || hasSortChanged) {
      if (hasFiltersChanged) _filters = filters;
      if (hasSortChanged) _sort = sort;
      notifyListeners();
    }
  }

  T? getFilterValue<T>() =>
      filters.firstWhereOrNull((e) => e.value.runtimeType == T)?.value;

  void updateFilter<T>(TransactionFilter<T> filter) {
    filters.removeWhere((e) => e.value.runtimeType == filter.value.runtimeType);
    filters.add(filter);
    notifyListeners();
  }

  void removeFilter<T>() {
    filters.removeWhere((e) => e.value.runtimeType == T);
    notifyListeners();
  }
}
