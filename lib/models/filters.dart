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

class Sort {
  final SortType sortType;
  final SortOrder sortOrder;

  const Sort(this.sortType, this.sortOrder);

  static Sort get defaultSort =>
      const Sort(SortType.date, SortOrder.descending);
}

class TransactionsRequest {
  final List<Filter>? filters;
  final Sort? sort;
  final int? pageKey;
  final int? pageSize;

  const TransactionsRequest({
    this.filters,
    this.sort,
    this.pageKey,
    this.pageSize,
  });

  @override
  bool operator ==(other) {
    return other is TransactionsRequest &&
        filters == other.filters &&
        sort == other.sort &&
        pageKey == other.pageKey &&
        pageSize == other.pageSize;
  }

  @override
  int get hashCode => Object.hash(filters, sort, pageKey, pageSize);
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
      table.title.lower().equals(text.toLowerCase()) |
      table.notes.lower().equals(text.toLowerCase());
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

/// Base filter for any transaction that is associated with the specified container.
///
/// Container objects include Categories, Accounts, and Goals.
sealed class ContainerFilter extends Filter {
  /// Whether to include transactions that have the specified container
  /// set to null.
  final bool includeNull;

  ContainerFilter({this.includeNull = false});

  TextColumn getColumn(Transactions table);

  /// A list of container object IDs.
  List<String> get itemIds;

  @override
  Expression<bool> buildCondition(Transactions table) {
    final column = getColumn(table);

    if (itemIds.isEmpty && includeNull) {
      return column.isNull();
    } else if (itemIds.isNotEmpty && includeNull) {
      return column.isIn(itemIds) | column.isNull();
    } else if (itemIds.isNotEmpty) {
      return column.isIn(itemIds);
    } else {
      return const Constant(false);
    }
  }
}

/// Filter for transactions associated with the specified [categories].
final class CategoryFilter extends ContainerFilter {
  final List<CategoryWithAmount> categories;

  CategoryFilter(this.categories, {super.includeNull});

  @override
  List<String> get itemIds => categories.map((e) => e.category.id).toList();

  @override
  TextColumn getColumn(Transactions table) => table.category;
}

/// Filter for transactions associated with the specified [accounts].
final class AccountFilter extends ContainerFilter {
  final List<AccountWithAmount> accounts;

  AccountFilter(this.accounts, {super.includeNull});

  @override
  List<String> get itemIds => accounts.map((e) => e.account.id).toList();

  @override
  TextColumn getColumn(Transactions table) => table.accountId;
}

/// Filter for transactions associated with the specified [goals].
final class GoalFilter extends ContainerFilter {
  final List<GoalWithAmount> goals;

  GoalFilter(this.goals, {super.includeNull});

  @override
  List<String> get itemIds => goals.map((e) => e.goal.id).toList();

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
