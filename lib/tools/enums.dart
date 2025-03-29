enum ObjectManageMode { add, edit } // Normal enum

enum AmountFilterType { greaterThan, lessThan, exactly }

// Enums with values, in case I need to store them in a database
enum TransactionType {
  expense(0),
  income(1);

  const TransactionType(this.value);
  final int value;
}

enum CategoryResetIncrement {
  daily(1),
  weekly(2),
  biweekly(3),
  monthly(4),
  yearly(5),
  never(0);

  const CategoryResetIncrement(this.value);
  final num value;

  factory CategoryResetIncrement.fromValue(int value) {
    return values.firstWhere((e) => e.value == value);
  }

  String getText() => switch (value) {
        1 => "Day",
        2 => "Week",
        3 => "Two Weeks",
        4 => "Month",
        5 => "Year",
        0 => "Never Reset",
        _ => "Error"
      };
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
