import 'dart:async';

import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/filters.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';

class TransactionProvider extends ChangeNotifier {
  // Allows the rest of the app to know when transaction filters
  // change
  List<TransactionFilter> _filters = [];
  Sort _sort = const Sort(SortType.date, SortOrder.descending);

  List<TransactionFilter> get filters => _filters;
  Sort get sort => _sort;

  void update(
      {List<TransactionFilter>? filters, Sort? sort, bool notify = true}) {
    bool hasFiltersChanged = filters != null && filters != _filters;
    bool hasSortChanged = sort != null && sort != _sort;

    if (hasFiltersChanged || hasSortChanged) {
      if (hasFiltersChanged) _filters = filters;
      if (hasSortChanged) _sort = sort;
      if (notify) notifyListeners();
    }
  }

  T? getFilterValue<T>() =>
      filters.firstWhereOrNull((e) => e.value.runtimeType == T)?.value;

  void updateFilter<T>(TransactionFilter<T> filter) {
    filters.removeWhere((e) => e.value.runtimeType == filter.value.runtimeType);
    filters.add(filter);
    notifyListeners();
  }

  void removeFilter<T>({Type? filterType}) {
    filters.removeWhere((e) => e.value.runtimeType == (filterType ?? T));
    notifyListeners();
  }
}

class DeletionManager {
  late final TransactionDao dao;
  late final SnackbarProvider snackbarProvider;

  // The int represents the list's hash code.
  final Map<List<String>, Timer> _activeDeleteTimers = {};

  DeletionManager(BuildContext context) {
    dao = context.read<TransactionDao>();
    snackbarProvider = context.read<SnackbarProvider>();
  }

  void dispose() {
    for (var timer in _activeDeleteTimers.values) {
      timer.cancel();
    }
    _activeDeleteTimers.clear();
  }

  void _cancelTimer(List<String> objectIds) {
    _activeDeleteTimers[objectIds]?.cancel();
    _activeDeleteTimers.remove(objectIds);
  }

  void _undoDeletion<T>(List<String> objectIds) {
    _cancelTimer(objectIds);

    if (T == Transaction) {
      dao.unmarkTransactionsAsDeleted(objectIds);
    } else if (T == Category) {
      dao.unmarkCategoryAsDeleted(objectIds.single);
    } else {
      throw "Unexpected Type $T";
    }
  }

  void _deletePermanently<T>(List<String> objectIds) {
    if (T == Transaction) {
      dao.permanentlyDeleteTransactions(objectIds);
    } else if (T == Category) {
      dao.permanentlyDeleteCategory(objectIds.single);
    }
    _activeDeleteTimers.remove(objectIds);
  }

  void stageObjectsForDeletion<T>(List<String> objectIds) {
    Future deletionFuture;

    if (T == Transaction) {
      deletionFuture = dao.markTransactionsAsDeleted(objectIds);
    } else if (T == Category) {
      deletionFuture = dao.markCategoryAsDeleted(objectIds.single);
    } else {
      throw "Unexpected type $T";
    }

    deletionFuture.then((_) {
      _cancelTimer(objectIds);

      final timer = Timer(const Duration(seconds: 5), () {
        snackbarProvider.hideCurrentSnackBar();
        _deletePermanently<T>(objectIds);
      });
      _activeDeleteTimers[objectIds] = timer;

      snackbarProvider.showSnackBar(
          SnackBar(
              content: Text(
                  "${T == Transaction ? objectIds.length == 1 ? 'Transaction' : 'Transactions' : 'Category'} deleted"),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                  label: "UNDO", onPressed: () => _undoDeletion<T>(objectIds))),
          snackbarCallback: (reason) {
        if (_activeDeleteTimers.containsKey(objectIds) &&
            reason != SnackBarClosedReason.action) {
          // The snackbar was closed by the user, no reason to keep the timers going
          _cancelTimer(objectIds);
          _deletePermanently<T>(objectIds);
        }
      });
    });
  }

  // void stageObjectsForArchival<T>(List<String> objectIds) {
  //   Future archivalFuture;

  //   if (T == Transaction) {
  //     archivalFuture = dao.archiveTransaction();
  //   }
  // }
}
