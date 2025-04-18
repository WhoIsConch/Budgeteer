import 'dart:math';

import 'package:budget/tools/filters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget/tools/enums.dart';

class Category {
  final String name;
  double balance;
  CategoryResetIncrement resetIncrement;
  bool allowNegatives;
  String? id;
  Color? color;
  DocumentSnapshot? snapshot;

  Category({
    this.id,
    required this.name,
    this.color,
    this.balance = 0,
    this.resetIncrement = CategoryResetIncrement.never,
    this.allowNegatives = true,
    this.snapshot,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      name: map['name'],
      balance: map['balance'],
      resetIncrement: CategoryResetIncrement.fromValue(map['resetIncrement']),
      allowNegatives: map['allowNegatives'] != 0,
      color: Color(map['color']),
    );
  }

  factory Category.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();

    return Category(
        id: snapshot.id,
        snapshot: snapshot,
        name: data?['name'],
        balance: data?['balance'],
        resetIncrement:
            CategoryResetIncrement.fromValue(data?['resetIncrement']),
        allowNegatives: data?['allowNegatives'],
        color: Color(data?['color']));
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'balance': balance,
      'resetIncrement': resetIncrement.value,
      'allowNegatives': allowNegatives,
      'color': color?.toARGB32() ?? genColor()
    };
  }

  int genColor() => Color((Random().nextDouble() * 0xFFFFFF).toInt())
      .withAlpha(255)
      .toARGB32();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'balance': balance,
      'resetIncrement': resetIncrement.value,
      'allowNegatives': allowNegatives ? 1 : 0,
      'color': color?.toARGB32() ?? genColor()
    };
  }

  DateTimeRange? getDateRange() {
    DateTimeRange? cumRange;
    DateTime now = DateTime.now();

    switch (resetIncrement) {
      case CategoryResetIncrement.daily:
        cumRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
        break;
      case CategoryResetIncrement.weekly:
        // Get the weekly DateTimeRange
        // First, subtract one from the weekday number (1-7)
        // Then subtract that many days from the current date
        // For example, (2025, 3, 29) would have 6 as a weekday
        // So subtract 1 from 6 to get 5, then 29 - 5 = 24 (monday)
        DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
        cumRange = DateTimeRange(
            start: DateTime(now.year, now.month, weekStart.day), end: now);
        break;

      case CategoryResetIncrement.monthly:
        // Get the Month to Date
        cumRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
        break;

      case CategoryResetIncrement.yearly:
        cumRange = DateTimeRange(
          start: DateTime(now.year),
          end: now,
        );
        break;

      case _:
        break;
    }

    return cumRange;
  }

  String getTimeUntilNextReset({DateTime? fromDate}) {
    DateTime now = fromDate ?? DateTime.now();
    DateTime nextReset;

    switch (resetIncrement) {
      case CategoryResetIncrement.daily:
        // Next day at midnight
        nextReset = DateTime(now.year, now.month, now.day + 1);
        break;
      case CategoryResetIncrement.weekly:
        // Next Monday at midnight
        nextReset = DateTime(now.year, now.month, now.day + (8 - now.weekday));
        break;
      case CategoryResetIncrement.monthly:
        // First day of next month
        if (now.month == 12) {
          nextReset = DateTime(now.year + 1, 1, 1);
        } else {
          nextReset = DateTime(now.year, now.month + 1, 1);
        }
        break;
      case CategoryResetIncrement.yearly:
        // First day of next year
        nextReset = DateTime(now.year + 1, 1, 1);
        break;
      default:
        return "";
    }

    Duration timeLeft = nextReset.difference(now);
    int days = timeLeft.inDays;
    int hours = timeLeft.inHours % 24;
    int minutes = timeLeft.inMinutes % 60;

    if (days > 30) {
      int months = days ~/ 30;
      return months == 1 ? "a month" : "$months months";
    } else if (days >= 7) {
      int weeks = days ~/ 7;
      return weeks == 1 ? "a week" : "$weeks weeks";
    } else if (days > 0) {
      return days == 1 ? "a day" : "$days days";
    } else if (hours > 0) {
      return hours == 1 ? "an hour" : "$hours hours";
    } else {
      return minutes == 1 ? "a minute" : "$minutes minutes";
    }
  }
}

class Transaction {
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  String? id;
  String category;
  String? location;
  String? notes;
  DocumentSnapshot? snapshot;

  Transaction(
      {this.id,
      required this.title,
      required this.amount,
      required this.date,
      required this.type,
      this.category = "",
      this.location,
      this.notes,
      this.snapshot});

  @override
  String toString() {
    return 'Transaction{id: $id, title: $title, amount: $amount, date: $date}';
  }

  @override
  bool operator ==(Object other) => other is Transaction && other.id == id;

  @override
  int get hashCode => id.hashCode;

  String formatDate() {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  Map<String, dynamic> toMap() {
    return {
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
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      type: TransactionType.values[map['type']],
      category: map['category'],
      location: map['location'],
      notes: map['notes'],
    );
  }

  factory Transaction.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();

    return Transaction(
      id: snapshot.id,
      snapshot: snapshot,
      title: data?['title'],
      amount: data?['amount'],
      date: data?['date'].toDate(),
      type: TransactionType.values[data?['type']],
      category: data?['category'],
      location: data?['location'],
      notes: data?['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'type': type.value,
      'category': category,
      'location': location,
      'notes': notes,
    };
  }

  Transaction copyWith({
    String? id,
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
  // Allows the rest of the app to know when a transactin
  // changes
  final FirestoreDatabaseHelper _helper = FirestoreDatabaseHelper();
  bool isLoading = false;
  List<Category> _categoriesPendingRemoval = [];
  List<Transaction> _transactionsPendingRemoval = [];
  List<Category> _categories = [];

  List<Category> get categories => _categoriesPendingRemoval.isEmpty
      ? _categories
      : _categories
          .where((e) => !_categoriesPendingRemoval.contains(e))
          .toList();

  List<Transaction> get transactionsPendingRemoval =>
      _transactionsPendingRemoval;

  TransactionProvider() {
    _listenToCategories();
  }

  void _listenToCategories() {
    _helper.getCategoriesStream().listen((data) {
      _categories = data;
      notifyListeners();
    });
  }

  Future<void> createDummyData() async {
    Random random = Random();

    // Reduced list of categories for better chart density
    List<String> expenseCategories = [
      "Groceries",
      "Dining",
      "Entertainment",
      "Shopping",
      "Transportation",
      "Utilities"
    ];

    List<String> incomeCategories = ["Salary", "Freelance", "Investments"];

    // Create actual Category objects
    List<Category> expenseCats = [];
    List<Category> incomeCats = [];

    for (String name in expenseCategories) {
      Category cat = await addCategory(Category(name: name));
      expenseCats.add(cat);
    }

    for (String name in incomeCategories) {
      Category cat = await addCategory(Category(name: name));
      incomeCats.add(cat);
    }

    // Transaction title templates
    Map<String, List<String>> transactionTitles = {
      "Groceries": [
        "Supermarket",
        "Local Store",
        "Farmer's Market",
        "Convenience Store"
      ],
      "Dining": ["Restaurant", "Coffee Shop", "Food Delivery", "Fast Food"],
      "Entertainment": ["Movies", "Concert", "Gaming", "Streaming Service"],
      "Shopping": [
        "Clothing Store",
        "Electronics",
        "Online Shopping",
        "Department Store"
      ],
      "Transportation": [
        "Gas",
        "Public Transit",
        "Ride Share",
        "Car Maintenance"
      ],
      "Utilities": ["Electric Bill", "Water Bill", "Internet", "Phone Bill"],
      "Salary": ["Monthly Salary", "Paycheck", "Direct Deposit"],
      "Freelance": ["Client Payment", "Project Fee", "Contract Work"],
      "Investments": ["Dividend", "Stock Sale", "Interest Income"]
    };

    // Generate more transactions per category
    List<DateTime> timestamps = [];

    // January to April 2025
    for (int month = 1; month <= 4; month++) {
      int daysInMonth = DateTime(2025, month + 1, 0).day;

      // Create more consistent transactions for each category throughout the month
      for (int day = 1; day <= daysInMonth; day++) {
        DateTime date = DateTime(2025, month, day);
        int weekday = date.weekday;
        bool isWeekend = weekday >= 6;

        // Ensure we have transactions for most categories almost every day
        // This creates denser category representation over time
        for (Category cat in expenseCats) {
          // Skip some days randomly but maintain high frequency
          if (random.nextDouble() < 0.8) {
            // 80% chance of transaction for this category today
            int transactionsForCategory =
                random.nextInt(3) + 1; // 1-3 transactions per category per day

            // Add more on weekends for certain categories
            if (isWeekend &&
                (cat.name == "Dining" ||
                    cat.name == "Entertainment" ||
                    cat.name == "Shopping")) {
              transactionsForCategory += random.nextInt(2) + 1;
            }

            // Specific category patterns
            if (cat.name == "Groceries" && (weekday == 1 || weekday == 6)) {
              // Monday and Saturday grocery shopping
              transactionsForCategory += 2;
            }

            if (cat.name == "Utilities" && day <= 5) {
              // Bills at beginning of month
              transactionsForCategory += 1;
            }

            // Generate timestamps for this category today
            for (int i = 0; i < transactionsForCategory; i++) {
              int hour = 8 + random.nextInt(14);
              int minute = random.nextInt(60);
              timestamps.add(DateTime(2025, month, day, hour, minute));
            }
          }
        }

        // Income transactions are less frequent
        for (Category cat in incomeCats) {
          // Salary typically twice a month
          if (cat.name == "Salary" && (day == 15 || day == daysInMonth)) {
            timestamps.add(DateTime(2025, month, day, 9, 0)); // Morning deposit
          }
          // Other income more randomly distributed
          else if (random.nextDouble() < 0.15) {
            // 15% chance per day
            int hour = 8 + random.nextInt(14);
            int minute = random.nextInt(60);
            timestamps.add(DateTime(2025, month, day, hour, minute));
          }
        }
      }
    }

    // Sort timestamps chronologically
    timestamps.sort();

    // Generate transactions
    for (DateTime timestamp in timestamps) {
      // First determine if it's income or expense
      bool isIncome =
          random.nextDouble() < 0.2; // 20% income, 80% expense ratio

      // Select category
      Category selectedCategory;
      if (isIncome) {
        selectedCategory = incomeCats[random.nextInt(incomeCats.length)];
      } else {
        selectedCategory = expenseCats[random.nextInt(expenseCats.length)];

        // Override random selection to ensure specific date patterns
        // This makes certain categories appear more consistently on certain days
        int day = timestamp.day;
        int weekday = timestamp.weekday;

        if (day <= 5 && random.nextDouble() < 0.7) {
          // Beginning of month more likely to be utilities
          selectedCategory =
              expenseCats.firstWhere((cat) => cat.name == "Utilities");
        } else if ((weekday == 6 || weekday == 7) &&
            random.nextDouble() < 0.6) {
          // Weekends more likely to be entertainment or dining
          List<String> weekendCats = ["Entertainment", "Dining"];
          String weekendCat = weekendCats[random.nextInt(weekendCats.length)];
          selectedCategory =
              expenseCats.firstWhere((cat) => cat.name == weekendCat);
        } else if (weekday >= 1 && weekday <= 5 && random.nextDouble() < 0.5) {
          // Weekdays more likely to be transportation or lunch (dining)
          List<String> weekdayCats = ["Transportation", "Dining"];
          String weekdayCat = weekdayCats[random.nextInt(weekdayCats.length)];
          selectedCategory =
              expenseCats.firstWhere((cat) => cat.name == weekdayCat);
        }
      }

      // Get realistic title for category
      List<String> possibleTitles =
          transactionTitles[selectedCategory.name] ?? ["Payment"];
      String title = possibleTitles[random.nextInt(possibleTitles.length)];

      // Generate amount based on category
      double amount;
      if (isIncome) {
        if (selectedCategory.name == "Salary") {
          amount = 1500.0 + random.nextDouble() * 2500.0;
        } else if (selectedCategory.name == "Investments") {
          amount = 100.0 + random.nextDouble() * 500.0;
        } else {
          amount = 200.0 + random.nextDouble() * 800.0; // Freelance
        }
      } else {
        // Expense amounts vary by category
        switch (selectedCategory.name) {
          case "Groceries":
            amount = 20.0 + random.nextDouble() * 120.0;
            break;
          case "Dining":
            amount = 10.0 + random.nextDouble() * 80.0;
            break;
          case "Entertainment":
            amount = 15.0 + random.nextDouble() * 100.0;
            break;
          case "Shopping":
            amount = 25.0 + random.nextDouble() * 200.0;
            break;
          case "Transportation":
            amount = 5.0 + random.nextDouble() * 60.0;
            break;
          case "Utilities":
            amount = 50.0 + random.nextDouble() * 150.0;
            break;
          default:
            amount = 10.0 + random.nextDouble() * 50.0;
        }
      }

      // Round to 2 decimal places
      amount = double.parse(amount.toStringAsFixed(2));

      // Create transaction
      addTransaction(Transaction(
          category: selectedCategory.name,
          title: title,
          amount: amount,
          date: timestamp,
          type: isIncome ? TransactionType.income : TransactionType.expense));
    }
  }

  Future<Transaction> addTransaction(Transaction transaction) async {
    return await _helper.createTransaction(transaction);
  }

  void updateTransaction(Transaction transaction) async {
    await _helper.updateTransaction(transaction);
  }

  void deleteTransaction(Transaction transaction) async {
    await _helper.deleteTransaction(transaction);
  }

  Future<Category> addCategory(Category category) async {
    return await _helper.createCategory(category);
  }

  Future<void> updateCategory(Category category) async {
    await _helper.updateCategory(category);
  }

  Future<void> deleteCategory(Category category) async {
    await _helper.deleteCategory(category);
  }

  Future<Category?> getCategory(String id) => _helper.getCategoryById(id);

  Future<double> getTotalAmount(
      {TransactionType? type,
      Category? category,
      DateTimeRange? dateRange}) async {
    return await _helper.getTotalAmount(
            type: type, category: category, dateRange: dateRange) ??
        0;
  }

  Query<Transaction> getQuery(
      {List<TransactionFilter>? filters,
      Sort? sort,
      DocumentSnapshot? startAfter,
      int? limit}) {
    return _helper.getTransactions(
        filters: filters, sort: sort, startAfter: startAfter, limit: limit);
  }

  Stream<List<Transaction>> getQueryStream(Query<Transaction> query) {
    return query
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  void addPendingCategory(Category category) {
    _categoriesPendingRemoval.add(category);
    notifyListeners();
  }

  void deletePendingCategories() {
    for (Category category in _categoriesPendingRemoval) {
      _helper.deleteCategory(category);
    }
    _categoriesPendingRemoval = [];
    notifyListeners();
  }

  void removePendingCategory(Category category) {
    bool didRemove = _categoriesPendingRemoval.remove(category);

    if (didRemove) notifyListeners();
  }

  void stageTransactionsForRemoval(List<Transaction> transactions) {
    _transactionsPendingRemoval.addAll(transactions);
    notifyListeners();
  }

  void removeStagedTransactions(List<Transaction> transactions) {
    for (Transaction t in transactions) {
      _transactionsPendingRemoval.remove(t);
    }

    notifyListeners();
  }

  void deleteStagedTransactions() {
    for (Transaction t in _transactionsPendingRemoval) {
      _helper.deleteTransaction(t);
    }

    _transactionsPendingRemoval = [];
    notifyListeners();
  }
}

class FirestoreDatabaseHelper {
  final _db = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;
  late final DocumentReference<Map<String, dynamic>> _userDoc;

  CollectionReference<Transaction> get transactions =>
      _userDoc.collection('transactions').withConverter<Transaction>(
          fromFirestore: Transaction.fromFirestore,
          toFirestore: (Transaction transaction, _) =>
              transaction.toFirestore());

  CollectionReference<Category> get categories =>
      _userDoc.collection('categories').withConverter<Category>(
          fromFirestore: Category.fromFirestore,
          toFirestore: (Category category, _) => category.toFirestore());

  Future<void> initUser() async {
    if (_user == null) {
      return;
    }

    _userDoc = _db.collection("users").doc(_user.uid);

    DocumentSnapshot<Map<String, dynamic>> userDocData = await _userDoc.get();

    // The user document already exists, so we don't have to create it. We just
    // assigned it above.
    if (userDocData.exists) return;

    await _userDoc.set({});
  }

  FirestoreDatabaseHelper() {
    initUser();
  }

  Future<Transaction> createTransaction(Transaction transaction) async {
    var storedTran = await transactions.add(transaction);

    return (await storedTran.get()).data()!;
  }

  Future<bool> updateTransaction(Transaction transaction) async {
    // Since we're updating the transaction, it's going to be assumed that this
    // transaction has an ID. If it doesn't, that's a developer's skill issue.
    if (transaction.id == null) return false;

    await transactions.doc(transaction.id).update(transaction.toFirestore());

    return true;
  }

  Future<bool> deleteTransaction(Transaction transaction) async {
    // Also assume this has an ID. It's the only way to already know if this
    // transaction is real.
    if (transaction.id == null) return false;

    await transactions.doc(transaction.id).delete();
    return true;
  }

  Query<Transaction> getTransactions(
      {List<TransactionFilter>? filters,
      Sort? sort,
      DocumentSnapshot? startAfter,
      int? limit}) {
    // Lazy loading is expected to be handled by the user, not this class.
    Query query = transactions;

    if (filters != null) {
      for (TransactionFilter filter in filters) {
        switch (filter) {
          // filter.value should be of type AmountFilter
          case TransactionFilter<AmountFilter> f:
            switch (f.value.type) {
              case AmountFilterType.greaterThan:
                query =
                    query.where("amount", isGreaterThan: filter.value.amount);
                break;
              case AmountFilterType.lessThan:
                query = query.where("amount", isLessThan: filter.value.amount);
                break;
              case AmountFilterType.exactly || null:
                query = query.where("amount", isEqualTo: filter.value.amount);
                break;
            }
            // According to this convenient Github issue, if a field is being
            // filtered by < <= > or >= it also needs to have an "orderBy"
            // associated with that field in the same query. I guess the ultimate
            // sort doesn't need to be that field, though, so I'm not sure why
            // this exists. But it errors out otherwise
            // https://github.com/firebase/flutterfire/issues/13478
            query = query.orderBy("amount");
            break;
          case TransactionFilter<String> f:
            // filter.value should be of type String
            query = query.where(Filter.or(
              Filter("title", isEqualTo: f.value),
              Filter("notes", isEqualTo: f.value),
            ));
            break;
          case TransactionFilter<DateTimeRange> f:
            // filter.value should be of type DateTimeRange
            query = query
                .where(Filter.and(
                    Filter("date",
                        isGreaterThanOrEqualTo:
                            Timestamp.fromDate(f.value.start)),
                    Filter("date",
                        isLessThanOrEqualTo: Timestamp.fromDate(f.value.end))))
                .orderBy("date");
            // .where("date", isGreaterThanOrEqualTo: filter.value.start)
            // .where("date", isLessThanOrEqualTo: filter.value.end);
            break;
          case TransactionFilter<TransactionType> f:
            // filter.value should be of type TransactionType
            query = query.where("type", isEqualTo: f.value.value);
            break;
          case TransactionFilter<List<Category>> f:
            query = query.where("category", whereIn: f.value.map((e) => e.id));
            break;
        }
      }
    }

    if (sort != null) {
      String field = sort.sortType.name;

      query = query.orderBy(field,
          descending: sort.sortOrder == SortOrder.ascending ? false : true);
    } else {
      query = query.orderBy("date", descending: true);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.withConverter<Transaction>(
        fromFirestore: Transaction.fromFirestore,
        toFirestore: (Transaction transaction, _) => transaction.toFirestore());
  }

  Future<int?> getTransactionsAmount() async {
    // Get the total amount of transactions in the database

    return transactions
        .count()
        .get()
        .then((res) => res.count, onError: (_) => null);
  }

  Future<double?> getTotalAmount(
      {TransactionType? type,
      Category? category,
      DateTimeRange? dateRange}) async {
    // Get the total amount of money in a field
    Query query = type == null
        ? transactions
        : transactions.where('type', isEqualTo: type.value);

    if (category != null) {
      query = query.where("category", isEqualTo: category.id);
    }

    if (dateRange != null) {
      query = query.where(Filter.and(
          Filter("date",
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start)),
          Filter("date",
              isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end))));
    }

    return query.aggregate(sum("amount")).get().then(
          (value) => value.getSum("amount"),
          onError: (_) => null,
        );
  }

  Future<Category> createCategory(Category category) async {
    var storedCat = await categories.add(category);

    return (await storedCat.get()).data()!;
  }

  Future<bool> updateCategory(Category category) async {
    if (category.id == null) return false;

    await categories.doc(category.id).update(category.toFirestore());
    return true;
  }

  Future<bool> deleteCategory(Category category) async {
    if (category.id == null) return false;

    await categories.doc(category.id).delete();
    return true;
  }

  Future<Category?> getCategoryById(String id) async {
    return categories.doc(id).get().then(
          (value) => value.data(),
        );
  }

  Stream<List<Category>> getCategoriesStream() => categories
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}
