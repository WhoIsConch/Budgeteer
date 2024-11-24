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

  Transaction copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? category,
    String? location,
    String? notes,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      location: location ?? this.location,
      notes: notes ?? this.notes,
    );
  }
}

class TransactionProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Transaction> transactions = [];

  Future<void> loadTransactions() async {
    transactions = await _dbHelper.transactions();
    notifyListeners();
  }

  void addTransaction(Transaction transaction) {
    _dbHelper.insertTransaction(transaction).then((value) {
      transactions.add(transaction);
      notifyListeners();
    });
  }

  void removeTransaction(Transaction transaction) {
    _dbHelper.deleteTransaction(transaction).then((value) {
      transactions.remove(transaction);
      notifyListeners();
    });
  }

  void updateTransaction(Transaction transaction) {
    _dbHelper.updateTransaction(transaction).then((value) {
      final index = transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        transactions[index] = transaction.copyWith();
        notifyListeners();
      }
    });
  }

  double getAmountSpent(DateTimeRange? dateRange) {
    double amountSpent = 0.0;

    if (dateRange == null) {
      for (Transaction transaction in transactions) {
        if (transaction.type == TransactionType.expense) {
          amountSpent += transaction.amount;
        }
      }
      return amountSpent;
    }

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

  double getAmountEarned(DateTimeRange? dateRange) {
    double amountEarned = 0.0;

    if (dateRange == null) {
      for (Transaction transaction in transactions) {
        if (transaction.type == TransactionType.income) {
          amountEarned += transaction.amount;
        }
      }
      return amountEarned;
    }

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

  double getTotal(DateTimeRange? dateRange) {
    return getAmountEarned(dateRange) - getAmountSpent(dateRange);
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    return await openDatabase(join(await getDatabasesPath(), 'budget.db'),
        version: 1, onCreate: (Database db, int version) async {
      return db.execute(
        'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, type INTEGER, category TEXT, location TEXT, notes TEXT)',
      );
    });
  }

  Future<void> insertTransaction(Transaction transaction) async {
    final Database db = await database;

    await db.insert(
      'transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Transaction>> transactions() async {
    final Database db = await database;

    final List<Map<String, dynamic>> maps = await db.query('transactions');

    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final db = await database;

    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteTransaction(Transaction transaction) async {
    final db = await database;

    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<List<String>> getUniqueCategories() async {
    final db = await database;
    final result = await db.query('transactions',
        distinct: true,
        columns: ['category'],
        where: 'category IS NOT NULL',
        orderBy: 'category ASC');

    return result.map((row) => row['category'] as String).toList();
  }

  Future<void> close() async {
    final db = await database;

    await db.close();

    _db = null;
  }
}
