import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/enums.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

enum SortType { title, date, amount }

enum SortOrder { ascending, descending }

enum AmountFilterType {
  exactly('='),
  lessThan('<'),
  greaterThan('>');

  const AmountFilterType(this.symbol);

  final String symbol;
}

/// Defines a way Transactions queries can be sorted.
class Sort {
  final SortType sortType;
  final SortOrder sortOrder;

  const Sort(this.sortType, this.sortOrder);

  static Sort get defaultSort =>
      const Sort(SortType.date, SortOrder.descending);
}

class FilterTypeException implements Exception {
  final Type type;

  FilterTypeException(this.type);

  @override
  String toString() {
    return 'Type $type is not a valid Filter.';
  }
}

/// Represents a database filter.
sealed class Filter {
  /// Build an [Expression] to be used in a Drift query.
  Expression<bool> buildCondition(Transactions table);
}

/// Filters Transactions based on their [amount] and a [type].
///
/// Will search for transactions that are greater than, less than, or equal to
/// [amount].
final class AmountFilter extends Filter {
  final AmountFilterType type;
  final double amount;

  AmountFilter(this.type, this.amount);

  @override
  Expression<bool> buildCondition(Transactions table) => switch (type) {
    AmountFilterType.greaterThan => table.amount.isBiggerThanValue(amount),
    AmountFilterType.lessThan => table.amount.isSmallerThanValue(amount),
    AmountFilterType.exactly => table.amount.equals(amount),
  };
}

/// Filter transactions based on their title or notes text.
///
/// This is unfortunately a case-insensitive, exact match of the text in the
/// database until an alternative text search can be implemented.
final class TextFilter extends Filter {
  final String text;

  TextFilter(this.text);

  @override
  Expression<bool> buildCondition(Transactions table) =>
      table.title.contains(text) | table.notes.contains(text);
  // `contains` is case-insensitive
}

/// Filter for any transactions that have a date set in the specified
/// [dateRange].
///
/// Note how this does not filter transactions by their creation date, since
/// that date should not be user-facing and is only relevant when there are
/// multiple transactions set for the same day.
final class DateRangeFilter extends Filter {
  final DateTimeRange dateRange;

  DateRangeFilter(this.dateRange);

  @override
  Expression<bool> buildCondition(Transactions table) =>
      table.date.isBetweenValues(
        formatter.format(dateRange.start),
        formatter.format(dateRange.end),
      );
}

/// Filter for any transaction of type [type].
final class TypeFilter extends Filter {
  final TransactionType type;

  TypeFilter(this.type);

  @override
  Expression<bool> buildCondition(Transactions table) =>
      table.type.equals(type.value);
}

/// Filter whether a transaction is archived.
final class ArchivedFilter extends Filter {
  final bool isArchived;

  ArchivedFilter(this.isArchived);

  @override
  Expression<bool> buildCondition(Transactions table) =>
      table.isArchived.equals(isArchived);
}

/// Filter out transactions that are in the future
final class FutureFilter extends Filter {
  final bool includeFuture;

  FutureFilter(this.includeFuture);

  @override
  Expression<bool> buildCondition(Transactions table) {
    // If we shouldn't include future transactions, always compile this to true
    if (includeFuture) return Constant(true);

    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);

    return table.date.isSmallerOrEqualValue(formatter.format(date));
  }
}

/// Base filter for any transaction that is associated with the specified container.
///
/// Container objects include Categories, Accounts, and Goals.
///
/// [includeNull] specifies whether to include transactions that have null
/// containers. If [includeNull] is true and [itemIds] is empty,
/// the filter will show only transactions with an explicitly null container.
/// If [itemIds] is null, the filter will show transactions with any container
/// association, and if [itemIds] is null and [includeNull] is true, the filter
/// will show all transactions.
sealed class ContainerFilter extends Filter {
  /// Whether to include transactions that have the specified container
  /// set to null.
  final bool includeNull;

  ContainerFilter({this.includeNull = false});

  TextColumn getColumn(Transactions table);

  /// A list of container object IDs.
  ///
  /// If [itemIds] is null, this filter will include all containers. If
  /// [itemIds] is empty, this filter will include all containers except for null
  /// ones, unless [includeNull] is true.
  List<String>? get itemIds;

  @override
  Expression<bool> buildCondition(Transactions table) {
    final column = getColumn(table);

    if (itemIds == null) {
      if (!includeNull) {
        // If no item IDs are specified and we aren't to include null categories,
        // we give the user all categories except for null ones
        return column.isNotNull();
      } else {
        // If item IDs is null and we are to include null categories, they get
        // everything.
        return const Constant(true);
      }
    } else if (itemIds!.isEmpty && includeNull) {
      return column.isNull();
    } else if (itemIds!.isNotEmpty && includeNull) {
      return column.isIn(itemIds!) | column.isNull();
    } else if (itemIds!.isNotEmpty) {
      return column.isIn(itemIds!);
    } else {
      return const Constant(false);
    }
  }
}

/// Filter for transactions associated with the specified [categories].
final class CategoryFilter extends ContainerFilter {
  final List<CategoryWithAmount>? categories;

  CategoryFilter(this.categories, {super.includeNull});

  @override
  List<String>? get itemIds => categories?.map((e) => e.category.id).toList();

  @override
  TextColumn getColumn(Transactions table) => table.category;
}

/// Filter for transactions associated with the specified [accounts].
final class AccountFilter extends ContainerFilter {
  final List<AccountWithAmount>? accounts;

  AccountFilter(this.accounts, {super.includeNull});

  @override
  List<String>? get itemIds => accounts?.map((e) => e.account.id).toList();

  @override
  TextColumn getColumn(Transactions table) => table.accountId;
}

/// Filter for transactions associated with the specified [goals].
final class GoalFilter extends ContainerFilter {
  final List<GoalWithAmount>? goals;

  GoalFilter(this.goals, {super.includeNull});

  @override
  List<String>? get itemIds => goals?.map((e) => e.goal.id).toList();

  @override
  TextColumn getColumn(Transactions table) => table.goalId;
}

extension FilterQueryBuilder on List<Filter> {
  /// Compile a list of [Filter]s into one [Expression]
  Expression<bool> buildWhereClause(Transactions table) {
    // final validFilters = where((filter) => filter.isValid);

    // If the list of filters is empty, all transactions should be shown.
    if (isEmpty) {
      return const Constant(true);
    }

    return map(
      (filter) => filter.buildCondition(table),
    ).reduce((a, b) => a & b);
  }
}
