import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget/tools/enums.dart';

List<Transaction> emulatedTransactionCache = [];
int emulatedTransactionId = 0;

class Transaction {
  final int id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  String? category;
  String? location;
  String? notes;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    this.category,
    this.location,
    this.notes,
  });

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  void mockSave() {
    emulatedTransactionCache.add(this);
  }
}

class TransactionProvider extends ChangeNotifier {
  List<Transaction> transactions = [];

  void addTransaction(Transaction transaction) {
    transactions.add(transaction);
    notifyListeners();
  }

  void removeTransaction(Transaction transaction) {
    transactions.remove(transaction);
    notifyListeners();
  }

  void updateTransaction(Transaction transaction) {
    transactions[transactions
        .indexWhere((element) => element.id == transaction.id)] = transaction;
    notifyListeners();
  }

  double getAmountSpent(DateTimeRange dateRange) {
    double amountSpent = 0.0;

    for (Transaction transaction in transactions) {
      if (transaction.date
              .isAfter(dateRange.start.subtract(const Duration(days: 1))) &&
          transaction.date
              .isBefore(dateRange.end.add(const Duration(days: 1))) &&
          transaction.type == TransactionType.expense) {
        amountSpent += transaction.amount;
      }
    }

    return amountSpent;
  }

  double getAmountEarned(DateTimeRange dateRange) {
    double amountEarned = 0.0;

    for (Transaction transaction in transactions) {
      if (transaction.date
              .isAfter(dateRange.start.subtract(const Duration(days: 1))) &&
          transaction.date
              .isBefore(dateRange.end.add(const Duration(days: 1))) &&
          transaction.type == TransactionType.income) {
        amountEarned += transaction.amount;
      }
    }

    return amountEarned;
  }
}

void createMockTransactions() {
  // When actually getting data from the API, remember to truncate names that
  // are too long to fit on the screen. Maybe like limit it to 20 characters
  // or something.
  for (int i = 0; i < 10; i++) {
    DateTime date = DateTime.now().subtract(Duration(days: i));
    emulatedTransactionCache.add(
      Transaction(
        id: i,
        title: "Transaction $i",
        amount: i * 10.0,
        date: date,
        type: TransactionType.expense,
      ),
    );
  }
}
