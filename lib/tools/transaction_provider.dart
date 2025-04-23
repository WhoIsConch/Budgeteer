import 'dart:async';

import 'package:budget/database/app_database.dart';
import 'package:budget/tools/enums.dart';
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
  final TransactionDao dao;

  // The int represents the list's hash code.
  final Map<List<String>, Timer> _activeDeleteTimers = {};

  DeletionManager(this.dao);

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
    // Context so we can use the snackbars
    // "object" so we can keep our system DRY

    Future deletionFuture;

    if (T == Transaction) {
      deletionFuture = dao.markTransactionsAsDeleted(objectIds);
    } else if (T == Category) {
      deletionFuture = dao.markCategoryAsDeleted(objectIds.single);
    } else {
      throw "Unexpected type $T";
    }

    final messenger = scaffoldMessengerKey.currentState!;

    deletionFuture.then((_) {
      _cancelTimer(objectIds);

      final timer = Timer(const Duration(seconds: 5), () {
        messenger.hideCurrentSnackBar();
        _deletePermanently<T>(objectIds);
      });
      _activeDeleteTimers[objectIds] = timer;

      messenger.hideCurrentSnackBar();
      messenger
          .showSnackBar(SnackBar(
              content: Text(
                  "${T == Transaction ? objectIds.length == 1 ? 'Transaction' : 'Transactions' : 'Category'} deleted"),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                  label: "UNDO", onPressed: () => _undoDeletion<T>(objectIds))))
          .closed
          .then((reason) {
        if (_activeDeleteTimers.containsKey(objectIds) &&
            reason != SnackBarClosedReason.action) {
          // The snackbar was closed by the user, no reason to keep the timers going
          _cancelTimer(objectIds);
          _deletePermanently<T>(objectIds);
        }
      });
    }).catchError((error) {
      messenger.showSnackBar(
          SnackBar(content: Text("Error deleting object: $error")));
    });
  }
}
