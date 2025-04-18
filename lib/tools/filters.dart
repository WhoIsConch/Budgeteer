import 'package:collection/collection.dart';

enum SortType { name, date, amount }

enum SortOrder { ascending, descending }

enum AmountFilterType {
  exactly("="),
  lessThan("<"),
  greaterThan(">");

  const AmountFilterType(this.symbol);

  final String symbol;
}

class Sort {
  final SortType sortType;
  final SortOrder sortOrder;

  const Sort(this.sortType, this.sortOrder);
}

class TransactionFilter<T> {
  final T value;

  const TransactionFilter(this.value);

  @override
  bool operator ==(Object other) {
    return other is TransactionFilter && value == other.value;
  }

  @override
  int get hashCode => value.hashCode;
}

// Not by definition an enum but it works nonetheless
class AmountFilter {
  final AmountFilterType? type;
  final double? amount;

  AmountFilter({this.type, this.amount});

  bool isPopulated() {
    return type != null && amount != null;
  }
}

T? getFilterValue<T>(List<TransactionFilter> filters) {
  return filters.firstWhereOrNull((e) => e.value.runtimeType == T)?.value;
}

void updateFilter<T>(
    TransactionFilter<T> filter, List<TransactionFilter> filters) {
  filters.removeWhere((e) => e.value.runtimeType == filter.value.runtimeType);
  filters.add(filter);
}

void removeFilter<T>(List<TransactionFilter> filters) {
  filters.removeWhere((e) => e.value.runtimeType == T);
}

class FilterTypeException implements Exception {
  final Type type;

  FilterTypeException(this.type);

  @override
  String toString() {
    return "Type $type is not a valid Filter.";
  }
}
