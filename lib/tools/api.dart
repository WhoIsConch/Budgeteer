import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget/tools/enums.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

enum CategoryResetIncrement {
  daily(1),
  weekly(2),
  monthly(3),
  yearly(4),
  never(0);

  const CategoryResetIncrement(this.value);
  final num value;

  factory CategoryResetIncrement.fromValue(int value) {
    return values.firstWhere((e) => e.value == value);
  }
}

class Category {
  final String name;
  double balance;
  CategoryResetIncrement resetIncrement;
  int associatedTransactions;

  Category({
    required this.name,
    this.balance = 0,
    this.resetIncrement = CategoryResetIncrement.never,
    this.associatedTransactions = 0,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      name: map['name'],
      balance: map['balance'],
      resetIncrement: CategoryResetIncrement.fromValue(map['resetIncrement']),
      associatedTransactions: map['associatedTransactions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'balance': balance,
      'resetIncrement': resetIncrement.value,
      'associatedTransactions': associatedTransactions,
    };
  }
}

class Transaction {
  // DB v1
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

  Future<Category?> getCategoryFromTransaction(Transaction transaction) async {
    if (transaction.category == null) {
      return null;
    }

    return await _dbHelper.getCategory(transaction.category!);
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

  Future<void> close() async {
      final db = await database;

      await db.close();

      _db = null;
    }

  Future<Database> _initDatabase() async {
    return await openDatabase(join(await getDatabasesPath(), 'budget.db'),
        version: 1, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    // DBv1
    await db.execute(
      'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, type INTEGER, category TEXT, location TEXT, notes TEXT)',
    );
    // DBv2
    await db.execute(
        'CREATE TABLE categories(name STRING PRIMARY KEY, balance REAL, resetIncrement INTEGER, associatedTransactions INTEGER)');
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

      // Formerly searched through all transactions and returned the unique
      // category names from them.
      // final results = await db.query(
      //   'transactions',
      //   distinct: true,
      //   columns: ['category'],
      //   where: 'category IS NOT NULL AND category != ""',
      //   orderBy: 'category ASC',
      // );

      // Now searches through DB v2's `categories` table for all categories
      final results =
          await db.query('categories', columns: ['name'], orderBy: 'name ASC');
      return results.map((res) => res['name'] as String).toList();
    } catch (e) {
      print('error in getUniqueCats: $e');
      return [];
    }
  }

  Future<Category?> getCategory(String categoryName,
      {deleteIfUnused = true}) async {
    try {
      final db = await database;

      final results = await db.query(
        'categories',
        where: 'name = ?',
        whereArgs: [categoryName],
      );

      if (results.firstOrNull == null) {
        return null;
      }

      Category category = Category.fromMap(results.first);

      if (results.first['associatedTransactions']! as double <= 0 && deleteIfUnused) {
        deleteCategoryIfZero(category: category);
      }

      return category;
    } catch (e) {
      print("Error: $e");
      return null;
    }
  }

  Future<void> deleteCategoryIfZero(
      {String? categoryName,
      Category? category,
      bool subtractOne = false}) async {
    // Delete a category if there are no more transactions that rely on it.

    if (categoryName == null && category == null) {
      return;
    } else if (categoryName != null) {
      category = await getCategory(categoryName);
    } // If neither of these conditions are true, it means `category` is not
    // null and can be used as it is

    if (subtractOne) {
      category!.associatedTransactions -= 1;
    }

    if (category!.associatedTransactions <= 0) {
      // Delete the category if it is unused
      final db = await database;

      await db.delete(
        'categories',
        where: 'name = ?',
        whereArgs: [category.name],
      );
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final db = await database;

    List<Map> previous = await db
        .query('transactions', where: 'id = ?', whereArgs: [transaction.id]);

    if (previous.first['category'] != transaction.category) {
      deleteCategoryIfZero(categoryName: previous.first['category'], subtractOne: true);
    }

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

    deleteCategoryIfZero(categoryName: transaction.category, subtractOne: true);
  }

  }
