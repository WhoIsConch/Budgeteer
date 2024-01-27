import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget/tools/enums.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Transaction {
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  int? id;
  String? category;
  String? location;
  String? notes;

  Transaction({
    this.id,
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
      'type': type.value,
      'category': category,
      'location': location,
      'notes': notes,
    };
  }

  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      type: TransactionType.values[map['type']],
      category: map['category'],
      location: map['location'],
      notes: map['notes'],
    );
  }
}

class TransactionProvider extends ChangeNotifier {
  List<Transaction> transactions = [];

  void loadTransactions() async {
    transactions = await APIDatabase.transactions();
    notifyListeners();
  }

  void addTransaction(Transaction transaction) {
    APIDatabase.insertTransaction(transaction).then((value) {
      transactions.add(transaction);
      notifyListeners();
    });
  }

  void removeTransaction(Transaction transaction) {
    APIDatabase.deleteTransaction(transaction).then((value) {
      transactions.remove(transaction);
      notifyListeners();
    });
  }

  void updateTransaction(Transaction transaction) {
    APIDatabase.updateTransaction(transaction).then((value) {
      transactions[transactions
          .indexWhere((element) => element.id == transaction.id)] = transaction;
      notifyListeners();
    });
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

class APIDatabase {
  static Future<Database> database() async {
    return openDatabase(
      join(await getDatabasesPath(), 'budget.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, type INTEGER, category TEXT, location TEXT, notes TEXT)',
        );
      },
      version: 1,
    );
  }

  static Future<void> insertTransaction(Transaction transaction) async {
    final Database db = await database();

    await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Transaction>> transactions() async {
    final Database db = await database();

    final List<Map<String, dynamic>> maps = await db.query('transactions');

    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  static Future<void> updateTransaction(Transaction transaction) async {
    final db = await database();

    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  static Future<void> deleteTransaction(Transaction transaction) async {
    final db = await database();

    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }
}
