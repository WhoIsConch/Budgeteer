import 'package:intl/intl.dart';

class Transaction {
  final int id;
  final String title;
  final double amount;
  final DateTime date;
  String? category;
  String? location;
  String? notes;

  Transaction(
    this.id,
    this.title,
    this.amount,
    this.date,
  );

  @override
  String toString() {
    return 'Transaction{id: $id, title: $title, amount: $amount, date: $date}';
  }

  String formatDate() {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  String formatAmount() {
    return "\$${amount.toStringAsFixed(2)}";
  }
}

List<Transaction> getMockTransactions() {
  List<Transaction> transactions = [];

  // When actually getting data from the API, remember to truncate names that
  // are too long to fit on the screen. Maybe like limit it to 20 characters
  // or something.
  for (int i = 0; i < 10; i++) {
    DateTime date = DateTime.now().subtract(Duration(days: i));
    transactions.add(
      Transaction(
        i,
        "Transaction $i",
        i * 10.0,
        date,
      ),
    );
  }

  return transactions;
}
