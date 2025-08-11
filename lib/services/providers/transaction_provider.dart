import 'dart:async';
import 'dart:collection';

import 'package:budget/services/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/filters.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A ChangeNotifier provider that allows parts of the application to have
/// access to database filters and be notified when they change.
class TransactionProvider extends ChangeNotifier {
  // ignore: prefer_collection_literals
  final _filtersByType = LinkedHashMap<Type, Filter>();
  Sort _sort = const Sort(SortType.date, SortOrder.descending);

  UnmodifiableListView<Filter> get filters =>
      UnmodifiableListView(_filtersByType.values);
  Sort get sort => _sort;

  TransactionProvider() {
    setFilter(FutureFilter(false), notify: false);
    setFilter(ArchivedFilter(false), notify: false);
  }

  TransactionProvider.empty();

  /// Get a filter of the specified [T]
  T? getFilter<T extends Filter>() => _filtersByType[T] as T?;

  void setFilter<T extends Filter>(T filter, {bool notify = true}) {
    final before = _filtersByType[T];
    _filtersByType[T] = filter;

    // Only notify the listeners if something actually changed
    if (!identical(before, filter) && notify) notifyListeners();
  }

  void removeFilterOf<T extends Filter>({bool notify = true}) {
    final removed = _filtersByType.remove(T) != null;

    if (removed && notify) notifyListeners();
  }

  void removeFilterByType(Type type, {bool notify = true}) {
    final removed = _filtersByType.remove(type) != null;

    if (removed && notify) notifyListeners();
  }

  void update({List<Filter>? filters, Sort? sort, bool notify = true}) {
    bool changed = false;

    if (filters != null) {
      // ignore: prefer_collection_literals
      final next = LinkedHashMap<Type, Filter>();

      for (final f in filters) {
        next[f.runtimeType] = f;
      }

      if (!_mapsEqual(_filtersByType, next)) {
        _filtersByType
          ..clear()
          ..addAll(next);
        changed = true;
      }
    }

    if (sort != null && sort != _sort) {
      _sort = sort;
      changed = true;
    }

    if (changed && notify) notifyListeners();
  }

  bool _mapsEqual(
    LinkedHashMap<Type, Filter> a,
    LinkedHashMap<Type, Filter> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;

    final aKeys = a.keys.toList(growable: false);
    final bKeys = b.keys.toList(growable: false);

    for (var i = 0; i < aKeys.length; i++) {
      if (aKeys[i] != bKeys[i]) return false;
      if (!identical(a[aKeys[i]], b[bKeys[i]])) return false;
    }
    return true;
  }
}

class DeletionManager {
  late final AppDatabase db;
  late final SnackbarProvider snackbarProvider;

  // The int represents the list's hash code.
  final Map<List<String>, Timer> _activeDeleteTimers = {};

  DeletionManager(BuildContext context) {
    db = context.read<AppDatabase>();
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

    switch (T) {
      case Transaction:
        db.transactionDao.setTransactionsDeleted(objectIds, false);
        break;
      case Category:
        db.categoryDao.setCategoriesDeleted(objectIds, false);
        break;
      case Goal:
        db.goalDao.setGoalsDeleted(objectIds, false);
        break;
      case Account:
        db.accountDao.setAccountsDeleted(objectIds, false);
        break;
      case _:
        throw 'Unexpected Type $T';
    }
  }

  void _undoArchival<T>(List<String> objectIds) {
    _cancelTimer(objectIds);

    switch (T) {
      case Transaction:
        db.transactionDao.setTransactionsArchived(objectIds, false);
        break;
      case Category:
        db.categoryDao.setCategoriesArchived(objectIds, false);
        break;
      case Account:
        db.accountDao.setAccountsArchived(objectIds, false);
        break;
      case Goal:
        db.goalDao.setGoalsFinished(objectIds, false);
      case _:
        throw 'Unexpected Type $T';
    }
  }

  void _deletePermanently<T>(List<String> objectIds) {
    switch (T) {
      case Transaction:
        db.transactionDao.permanentlyDeleteTransactions(objectIds);
        break;
      case Category:
        db.categoryDao.permanentlyDeleteCategories(objectIds);
        break;
      case Goal:
        db.goalDao.permanentlyDeleteGoals(objectIds);
        break;
      case AccountDao:
        db.accountDao.permanentlyDeleteAccounts(objectIds);
      case _:
        throw 'Unexpected type $T';
    }

    _activeDeleteTimers.remove(objectIds);
  }

  void stageObjectsForDeletion<T>(List<String> objectIds) {
    Future deletionFuture;

    // "Make deletion manager DRYer,"" I write in a commit message, knowing
    // I reused just about the same exact switch statement in at least four
    // different methods
    String name;

    switch (T) {
      case Transaction:
        deletionFuture = db.transactionDao.setTransactionsDeleted(
          objectIds,
          true,
        );
        name = objectIds.length == 1 ? 'Transaction' : 'Transactions';
        break;
      case Category:
        deletionFuture = db.categoryDao.setCategoriesDeleted(objectIds, true);
        name = objectIds.length == 1 ? 'Category' : 'Categories';
        break;
      case Goal:
        deletionFuture = db.goalDao.setGoalsDeleted(objectIds, true);
        name = objectIds.length == 1 ? 'Goal' : 'Goals';
        break;
      case Account:
        deletionFuture = db.accountDao.setAccountsDeleted(objectIds, true);
        name = objectIds.length == 1 ? 'Account' : 'Accounts';
      case _:
        throw 'Unexpected type $T';
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
          content: Text('$name deleted'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => _undoDeletion<T>(objectIds),
          ),
        ),
        snackbarCallback: (reason) {
          if (_activeDeleteTimers.containsKey(objectIds) &&
              reason != SnackBarClosedReason.action) {
            // The snackbar was closed by the user, no reason to keep the timers going
            _cancelTimer(objectIds);
            _deletePermanently<T>(objectIds);
          }
        },
      );
    });
  }

  void stageObjectsForArchival<T>(List<String> objectIds) {
    Future archivalFuture;
    String deletedItemString;
    bool isSingle = objectIds.length == 1;

    switch (T) {
      case Transaction:
        deletedItemString = isSingle ? 'Transaction' : 'Transactions';
        archivalFuture = db.transactionDao.setTransactionsArchived(
          objectIds,
          true,
        );
        break;

      case Category:
        deletedItemString = isSingle ? 'Category' : 'Categories';
        archivalFuture = db.categoryDao.setCategoriesArchived(objectIds, true);
        break;

      case Account:
        deletedItemString = isSingle ? 'Account' : 'Accounts';
        archivalFuture = db.accountDao.setAccountsArchived(objectIds, true);
        break;

      case Goal:
        deletedItemString = isSingle ? 'Goal' : 'Goals';
        archivalFuture = db.goalDao.setGoalsFinished(objectIds, true);

      case _:
        throw 'Unexpected Type $T';
    }

    archivalFuture.then((_) {
      _cancelTimer(objectIds);

      final timer = Timer(const Duration(seconds: 5), () {
        snackbarProvider.hideCurrentSnackBar();
      });

      _activeDeleteTimers[objectIds] = timer;

      snackbarProvider.showSnackBar(
        SnackBar(
          content: Text(
            "$deletedItemString ${T == Goal ? 'marked as finished' : 'archived'}",
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => _undoArchival<T>(objectIds),
          ),
        ),
        snackbarCallback: (reason) {
          if (_activeDeleteTimers.containsKey(objectIds) &&
              reason != SnackBarClosedReason.action) {
            _cancelTimer(objectIds);
          }
        },
      );
    });
  }
}
