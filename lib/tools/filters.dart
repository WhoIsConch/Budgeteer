import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:flutter/material.dart';

enum SortType { name, date, amount }

enum SortOrder { ascending, descending }

enum AmountFilterType {
  exactly("="),
  lessThan("<"),
  greaterThan(">");

  const AmountFilterType(this.symbol);
  final String symbol;
}

abstract class TransactionFilter<T> {
  final T value;

  const TransactionFilter(this.value);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TransactionFilter) return false;
    if (value.runtimeType != other.value.runtimeType) return false;
    return value == other.value;
  }

  @override
  int get hashCode => Object.hash(value.runtimeType, value);
}

class StringFilter extends TransactionFilter<String> {
  StringFilter(String value) : super(value);
}

class CategoryFilter extends TransactionFilter {
  CategoryFilter(List<Category> value) : super(value);
}

class TypeFilter extends TransactionFilter<TransactionType> {
  TypeFilter(TransactionType value) : super(value);
}

class AmountFilter extends TransactionFilter<double> {
  final AmountFilterType amountType;
  AmountFilter(this.amountType, double value) : super(value);
}

class DateRangeFilter extends TransactionFilter<DateTimeRange> {
  DateRangeFilter(DateTimeRange value) : super(value);
}

class Sort {
  final SortType sortType;
  final SortOrder sortOrder;

  const Sort(this.sortType, this.sortOrder);
}
