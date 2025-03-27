enum TransactionManageMode { add, edit } // Normal enum

enum AmountFilterType { greaterThan, lessThan, exactly }

// Enums with values, in case I need to store them in a database
enum TransactionType {
  expense(0),
  income(1);

  const TransactionType(this.value);
  final int value;
}

enum PageType {
  home(0),
  transactions(1);

  const PageType(this.value);
  final int value;
}

// Not by definition an enum but it works nonetheless
class AmountFilter {
  final AmountFilterType? type;
  final double? value;

  AmountFilter({this.type, this.value});

  bool isPopulated() {
    return type != null && value != null;
  }
}
