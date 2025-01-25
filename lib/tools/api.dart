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

  factory Transaction.fromMap(Map<String, dynamic> map) {
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
  List<Transaction> _transactions = [];

  List<Transaction> get transactions => _transactions;

  Future<void> loadTransactions({
    DateTimeRange? dateRange,
    TransactionType? type,
  }) async {
    _transactions = await _dbHelper.getTransactions(
      dateRange: dateRange,
      type: type,
    );
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    final newTransaction = await _dbHelper.insertTransaction(transaction);

    _transactions.add(newTransaction);
    notifyListeners();
  }

  Future<void> removeTransaction(Transaction transaction) async {
    await _dbHelper.deleteTransaction(transaction);

    _transactions.removeWhere((t) => t.id == transaction.id);
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _dbHelper.updateTransaction(transaction);
    final index = _transactions.indexWhere((t) => t.id == transaction.id);

    if (index != -1) {
      _transactions[index] = transaction;
      notifyListeners();
    }
  }

  Future<double> getAmountSpent(DateTimeRange? dateRange) async {
    return await _dbHelper.getTotalAmount(
        dateRange: dateRange, type: TransactionType.expense);
  }

  Future<double> getAmountEarned(DateTimeRange? dateRange) async {
    return await _dbHelper.getTotalAmount(
      dateRange: dateRange,
      type: TransactionType.income,
    );
  }

  Future<double> getTotal(DateTimeRange? dateRange) async {
    final earned = await getAmountEarned(dateRange);
    final spent = await getAmountSpent(dateRange);

    return earned - spent;
  }

  Future<List<String>> getCategories() async {
    return await _dbHelper.getUniqueCategories();
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
        version: 1, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, type INTEGER, category TEXT, location TEXT, notes TEXT)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  Future<Transaction> insertTransaction(Transaction transaction) async {
    final Database db = await database;

    return transaction.copyWith(
      id: await db.insert(
        'transactions',
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      ),
    );
  }

  Future<List<Transaction>> getTransactions({
    DateTimeRange? dateRange,
    TransactionType? type,
  }) async {
    final Database db = await database;

    List<String> whereConditions = [];
    List<dynamic> whereArgs = [];

    if (dateRange != null) {
      whereConditions.add('date BETWEEN ? AND ?');
      whereArgs.addAll(
          [dateRange.start.toIso8601String(), dateRange.end.toIso8601String()]);
    }

    if (type != null) {
      whereConditions.add('type = ?');
      whereArgs.add(type.value);
    }

    final List<Map<String, dynamic>> maps = await db.query('transactions',
        where:
            whereConditions.isNotEmpty ? whereConditions.join(' AND ') : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null);

    return maps.map((map) => Transaction.fromMap(map)).toList();
  }

  Future<double> getTotalAmount({
    DateTimeRange? dateRange,
    required TransactionType type,
  }) async {
    final Database db = await database;

    List<String> whereConditions = ['type = ?'];
    List<dynamic> whereArgs = [type.value];

    if (dateRange != null) {
      whereConditions.add('date BETWEEN ? AND ?');
      whereArgs.addAll(
          [dateRange.start.toIso8601String(), dateRange.end.toIso8601String()]);
    }

    final result = await db.query(
      'transactions',
      columns: ['SUM(amount) as total'],
      where: whereConditions.join(' AND '),
      whereArgs: whereArgs,
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<String>> getUniqueCategories() async {
    try {
      final db = await database;

      final results = await db.query(
        'transactions',
        distinct: true,
        columns: ['category'],
        where: 'category IS NOT NULL AND category != ""',
        orderBy: 'category ASC',
      );

      return results.map((row) => row['category'] as String).toList();
    } catch (e) {
      print('error in getUniqueCats: $e');
      return [];
    }
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

  Future<void> close() async {
    final db = await database;

    await db.close();

    _db = null;
  }
}
