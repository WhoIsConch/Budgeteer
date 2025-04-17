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

class AmountFilter {
  final AmountFilterType type;
  final double value;

  const AmountFilter(this.type, this.value);
}

class TransactionFilter<T> {
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

class Sort {
  final SortType sortType;
  final SortOrder sortOrder;

  const Sort(this.sortType, this.sortOrder);
}

TransactionFilter<T>? getFilter<T>(List<TransactionFilter> filters) {
  TransactionFilter? filter = filters.firstWhereOrNull(
    (element) => element.value.runtimeType == T,
  );
  return filter as TransactionFilter<T>?;
}

T? getFilterValue<T>(List<TransactionFilter> filters) {
  TransactionFilter? filter = filters.firstWhereOrNull(
    (element) => element.runtimeType == T,
  );
  return filter?.value as T?;
}

void updateFilter<T>(
    List<TransactionFilter> filters, TransactionFilter<T> filter) {
  removeFilter<T>(filters);

  filters.add(filter);
}

void removeFilter<T>(List<TransactionFilter> filters) {
  int index = filters.indexWhere((e) => e.value.runtimeType == T);

  if (index != -1) {
    filters.remove(index);
  }
}
