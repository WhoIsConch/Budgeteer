enum PageType {
  home(0),
  transactions(1);

  const PageType(this.value);
  final int value;
}

enum TransactionManageMode { add, edit }

enum TransactionType { expense, income }
