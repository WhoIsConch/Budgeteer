import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
    };
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

Future<List<Transaction>> getTransactions(Database db) async {
  List<Map<String, dynamic>> maps = await db.query('transactions');
  return List.generate(maps.length, (i) {
    return Transaction(
      maps[i]['id'],
      maps[i]['title'],
      maps[i]['amount'],
      DateTime.parse(maps[i]['date']),
    );
  });
}

Future<void> insertTransaction(Database db, Transaction transaction) async {
  await db.insert(
    'transactions',
    transaction.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> updateTransaction(Database db, Transaction transaction) async {
  await db.update(
    'transactions',
    transaction.toMap(),
    where: 'id = ?',
    whereArgs: [transaction.id],
  );
}

Future<void> deleteTransaction(Database db, int id) async {
  await db.delete(
    'transactions',
    where: 'id = ?',
    whereArgs: [id],
  );
}
