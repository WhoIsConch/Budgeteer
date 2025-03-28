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
  bool isPermanent;
  int? id;

  Category({
    this.id,
    required this.name,
    this.balance = 0,
    this.resetIncrement = CategoryResetIncrement.never,
    this.associatedTransactions = 0,
    this.isPermanent = false,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      balance: map['balance'],
      resetIncrement: CategoryResetIncrement.fromValue(map['resetIncrement']),
      associatedTransactions: map['associatedTransactions'],
      isPermanent: map['isPermanent'] == 0 ? false : true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'resetIncrement': resetIncrement.value,
      'associatedTransactions': associatedTransactions,
      'isPermanent': isPermanent ? 1 : 0,
    };
  }
}

class Transaction {
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  int? id;
  String category;
  String? location;
  String? notes;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    this.category = "",
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

  Future<void> _incrementOrCreateCategory(String categoryName) async {
    Category? category = await _dbHelper.getCategory(categoryName);

    if (category == null) {
      await _dbHelper.createCategory(
          Category(name: categoryName, associatedTransactions: 1));
      return;
    }

    category.associatedTransactions++;
    await _dbHelper.updateCategory(category);
  }

  Future<void> _decrementOrDeleteCategory(String categoryName) async {
    Category? category = await _dbHelper.getCategory(categoryName);
    if (category == null) {
      return;
    }

    category.associatedTransactions--;

    if (category.associatedTransactions <= 0 && !category.isPermanent) {
      _dbHelper.deleteCategory(category.name);
      return;
    } else {
      category.associatedTransactions = 0;
    }

    _dbHelper.updateCategory(category);
  }

  Future<void> addTransaction(Transaction transaction) async {
    final newTransaction = await _dbHelper.insertTransaction(transaction);

    if (transaction.category.isNotEmpty) {
      _incrementOrCreateCategory(transaction.category);
    }

    _transactions.add(newTransaction);
    notifyListeners();
  }

  Future<void> removeTransaction(Transaction transaction) async {
    await _dbHelper.deleteTransaction(transaction);

    if (transaction.category.isNotEmpty) {
      _decrementOrDeleteCategory(transaction.category);
    }

    _transactions.removeWhere((t) => t.id == transaction.id);
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _dbHelper.updateTransaction(transaction);
    final index = _transactions.indexWhere((t) => t.id == transaction.id);

    Transaction oldTransaction = transactions[index];
    Transaction newTransaction = transaction;

    // Manage the category of this transaction.
    // If the category is not equal, that means they are both not null and
    // they are both not the same (which would mean the category is the same)
    if (newTransaction.category != oldTransaction.category) {
      if (newTransaction.category.isEmpty &&
          oldTransaction.category.isNotEmpty) {
        // Did the transaction change to nothing?
        _decrementOrDeleteCategory(oldTransaction.category);
      } else if (oldTransaction.category.isEmpty &&
          newTransaction.category.isNotEmpty) {
        // Did the transaction change from nothing?
        _incrementOrCreateCategory(newTransaction.category);
      } else {
        // If neither of them are null, but they are not equal to each other,
        // both the previous and current had a category that is now changed.
        // Update both of their categories.
        _decrementOrDeleteCategory(transactions[index].category);
        _incrementOrCreateCategory(transaction.category);
      }
    }

    if (index != -1) {
      _transactions[index] = transaction;
      notifyListeners();
    }
  }

  Future<Category?> getCategoryFromTransaction(Transaction transaction) async {
    if (transaction.category.isEmpty) {
      return null;
    }

    return await _dbHelper.getCategory(transaction.category);
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

  Future<List<Category>> getCategories() async {
    return await _dbHelper.getCategoriesList();
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
        version: 1, onCreate: _onCreate,
        onUpgrade: (Database db, int oldVersion, int newVersion) async {
      for (int version = oldVersion; version < newVersion; version++) {
        await _performUpgrade(db, version + 1);
      }
    });
  }

  Future<void> _onCreate(Database db, int newVersion) async {
    for (int version = 0; version < newVersion; version++) {
      await _performUpgrade(db, version + 1);
    }
  }

  static Future<void> _performUpgrade(Database db, int newVersion) async {
    switch (newVersion) {
      case 1:
        _dbUpdatesVersion_1(db);
    }
  }

  static Future<void> _dbUpdatesVersion_1(Database db) async {
    await db.execute(
      'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, date TEXT, type INTEGER, category TEXT, location TEXT, notes TEXT)',
    );
    await db.execute(
        'CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name STRING UNIQUE, balance REAL, resetIncrement INTEGER, associatedTransactions INTEGER, isPermanent INTEGER)');
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

  Future<List<Category>> getCategoriesList() async {
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
      final results = await db.query('categories', orderBy: 'name ASC');
      return results.map((res) => Category.fromMap(res)).toList();
    } catch (e) {
      print('error in getUniqueCats: $e');
      return [];
    }
  }

  Future<Category?> getCategory(String categoryName) async {
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

      return category;
    } catch (e) {
      print("Error: $e");
      return null;
    }
  }

  Future<void> deleteCategory(String categoryName) async {
    // Delete the category if it is unused
    final db = await database;

    await db.delete(
      'categories',
      where: 'name = ?',
      whereArgs: [categoryName],
    );
  }

  Future<Category> createCategory(Category category) async {
    final db = await database;

    await db.insert(
      'categories',
      category.toMap(),
    );

    print(category);
    return category;
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;

    await db.update('categories', category.toMap(),
        where: 'name = ?', whereArgs: [category.name]);
  }
}
