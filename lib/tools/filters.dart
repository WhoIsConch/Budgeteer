enum SortType { title, date, amount }

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

class AmountFilter {
  final AmountFilterType? type;
  final double? amount;

  AmountFilter({this.type, this.amount});

  bool isPopulated() {
    return type != null && amount != null;
  }
}

class TransactionsRequest {
  final List<TransactionFilter>? filters;
  final Sort? sort;
  final int? pageKey;
  final int? pageSize;

  const TransactionsRequest(
      {this.filters, this.sort, this.pageKey, this.pageSize});

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
    return "Type $type is not a valid Filter.";
  }
}
