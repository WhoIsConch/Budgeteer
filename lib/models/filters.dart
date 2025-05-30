import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
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

sealed class Filter {
  Expression<bool> buildCondition(Transactions table);
}

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

final class TextFilter extends Filter {
  final String text;

  TextFilter(this.text);

  @override
  Expression<bool> buildCondition(Transactions table) =>
      table.title.lower().equals(text.toLowerCase()) |
      table.notes.lower().equals(text.toLowerCase());
}

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

final class TypeFilter extends Filter {
  final TransactionType type;

  TypeFilter(this.type);

  @override
  Expression<bool> buildCondition(Transactions table) =>
      table.type.equals(type.value);
}

sealed class ContainerFilter extends Filter {
  final bool includeNull;

  ContainerFilter({this.includeNull = false});

  TextColumn getColumn(Transactions table);
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

final class CategoryFilter extends ContainerFilter {
  final List<Category> categories;

  CategoryFilter(this.categories, {super.includeNull});

  @override
  List<String> get itemIds => categories.map((e) => e.id).toList();

  @override
  TextColumn getColumn(Transactions table) => table.category;
}

final class AccountFilter extends ContainerFilter {
  final List<Account> accounts;

  AccountFilter(this.accounts, {super.includeNull});

  @override
  List<String> get itemIds => accounts.map((e) => e.id).toList();

  @override
  TextColumn getColumn(Transactions table) => table.accountId;
}

final class GoalFilter extends ContainerFilter {
  final List<Goal> goals;

  GoalFilter(this.goals, {super.includeNull});

  @override
  List<String> get itemIds => goals.map((e) => e.id).toList();

  @override
  TextColumn getColumn(Transactions table) => table.goalId;
}

extension FilterQueryBuilder on List<Filter> {
  Expression<bool> buildWhereClause(Transactions table) {
    // final validFilters = where((filter) => filter.isValid);

    // if (validFilters.isEmpty) {
    //   return const Constant(true);
    // }

    return map(
      (filter) => filter.buildCondition(table),
    ).reduce((a, b) => a & b);
  }
}
