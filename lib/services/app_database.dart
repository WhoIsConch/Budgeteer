import 'dart:math';

import 'package:budget/models/data.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/utils/tools.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color, DateTimeRange;
import 'package:intl/intl.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase, uuid;
import 'package:drift_sqlite_async/drift_sqlite_async.dart';

part 'app_database.g.dart';

final _formatter = DateFormat("yyyy-MM-dd");

int genColor() =>
    Color((Random().nextDouble() * 0xFFFFFF).toInt()).withAlpha(255).toARGB32();

class DateTextConverter extends TypeConverter<DateTime, String> {
  const DateTextConverter();

  @override
  DateTime fromSql(String fromDb) => _formatter.parseStrict(fromDb);

  @override
  String toSql(DateTime value) => _formatter.format(value);
}

class Transactions extends Table {
  @override
  String get tableName => "transactions";

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get date => text().map(const DateTextConverter())();
  IntColumn get type => intEnum<TransactionType>()();
  BoolColumn get isDeleted => boolean()
      .nullable()
      .withDefault(const Constant(false))
      .named('is_deleted')();
  TextColumn get notes => text().nullable()();

  TextColumn get category => text()
      .nullable()
      .named('category_id')
      .references(Categories, #id, onDelete: KeyAction.setNull)();

  TextColumn get accountId => text()
      .nullable()
      .named('account_id')
      .references(Accounts, #id, onDelete: KeyAction.setNull)();

  TextColumn get goalId => text()
      .nullable()
      .named('goal_id')
      .references(Goals, #id, onDelete: KeyAction.setNull)();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

extension TransactionExtensions on Transaction {
  String formatDate() {
    return DateFormat('MM/dd/yyyy').format(date);
  }
}

class ColorConverter extends TypeConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromSql(int fromDb) => Color(fromDb);

  @override
  int toSql(Color value) => value.toARGB32();
}

class Categories extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text()();

  IntColumn get resetIncrement => intEnum<CategoryResetIncrement>()
      .withDefault(const Constant(0))
      .named('reset_increment')();
  BoolColumn get allowNegatives =>
      boolean().withDefault(const Constant(false)).named('allow_negatives')();
  IntColumn get color =>
      integer().clientDefault(genColor).map(const ColorConverter())();
  RealColumn get balance => real().nullable()();
  BoolColumn get isDeleted => boolean()
      .nullable()
      .withDefault(const Constant(false))
      .named('is_deleted')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

extension CategoriesExtension on Category {
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

class Accounts extends Table {
  @override
  get tableName => 'accounts';

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text()();

  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();
  BoolColumn get isArchived =>
      boolean().withDefault(const Constant(false)).named('is_archived')();
}

class Goals extends Table {
  @override
  get tableName => 'goals';

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text()();
  RealColumn get cost => real()();
  TextColumn get dueDate =>
      text().nullable().named('due_date').map(const DateTextConverter())();
  BoolColumn get isFinished =>
      boolean().withDefault(const Constant(false)).named('is_finished')();
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();
}

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(AppDatabase db) : super(db);

  Stream<List<Transaction>> watchTransactionsPage({
    List<TransactionFilter>? filters,
    Sort? sort,
    int? limit,
    int? offset,
  }) {
    var query = db.select(db.transactions)
      ..where((t) => t.isDeleted.equals(true).not());

    filters ??= [];

    for (final TransactionFilter filter in filters) {
      switch (filter) {
        case TransactionFilter<AmountFilter> f:
          switch (f.value.type!) {
            case AmountFilterType.greaterThan:
              query = query
                ..where((t) => t.amount.isBiggerThanValue(f.value.amount!));
              break;
            case AmountFilterType.lessThan:
              query = query
                ..where((t) => t.amount.isSmallerThanValue(f.value.amount!));
              break;
            case AmountFilterType.exactly:
              query = query..where((t) => t.amount.equals(f.value.amount!));
              break;
          }
          break;
        case TransactionFilter<String> f:
          // TODO: Figure out if this can be converted to partial text search
          query = query
            ..where((t) =>
                t.title.lower().equals(f.value.toLowerCase()) |
                t.notes.lower().equals(f.value.toLowerCase()));
          break;
        case TransactionFilter<DateTimeRange> f:
          query = query
            ..where((t) =>
                t.date.isBiggerOrEqualValue(_formatter.format(f.value.start)) &
                t.date.isSmallerOrEqualValue(_formatter.format(f.value.end)));
          break;
        case TransactionFilter<TransactionType> f:
          query = query..where((t) => t.type.equals(f.value.value));
          break;
        case TransactionFilter<List<Category>> f:
          query = query
            ..where((t) => t.category.isIn(f.value.map((e) => e.id)));
          break;
      }
    }

    if (sort != null) {
      OrderingMode sortMode = sort.sortOrder == SortOrder.ascending
          ? OrderingMode.asc
          : OrderingMode.desc;

      query = query
        ..orderBy([
          (t) => OrderingTerm(
              mode: sortMode,
              expression: switch (sort.sortType) {
                SortType.amount => t.amount,
                SortType.date => t.date,
                SortType.title => t.title
              } as Expression<Object>)
        ]);
    } else {
      query = query..orderBy([(t) => OrderingTerm.desc(t.date)]);
    }

    if (limit != null) {
      query = query..limit(limit, offset: offset);
    }

    return query.watch();
  }

  Stream<double?> watchTotalAmount({
    TransactionType? type,
    DateTimeRange? dateRange,
    Category? category,
    bool nullCategory = false,
    bool net = true,
  }) {
    var query = select(transactions)
      ..where((t) => t.isDeleted.equals(true).not());

    if (type != null) {
      query = query..where((t) => t.type.equalsValue(type));
    }

    if (category != null) {
      query = query..where((t) => t.category.equals(category.id));
    } else if (nullCategory) {
      query = query..where((t) => t.category.isNull());
    }

    if (dateRange != null) {
      query = query
        ..where((t) => t.date.isBetweenValues(
            _formatter.format(dateRange.start),
            _formatter.format(dateRange.end)));
    }

    if (type == null && net) {
      // If the type is null, we want to get the net amount
      final signedAmount = CaseWhenExpression(cases: [
        CaseWhen(transactions.type.equalsValue(TransactionType.income),
            then: transactions.amount),
        CaseWhen(transactions.type.equalsValue(TransactionType.expense),
            then: -transactions.amount)
      ], orElse: const Constant(0.0))
          .sum();

      return query
          .addColumns([signedAmount])
          .map((row) => row.read(signedAmount))
          .watchSingle();
    }

    return query
        .addColumns([transactions.amount.sum()])
        .map((row) => row.read(transactions.amount.sum()))
        .watchSingle();
  }

  Future<FinancialDataPoint> getPointFromRange(DateTimeRange range) async {
    final totalSpent =
        await watchTotalAmount(dateRange: range, type: TransactionType.expense)
            .first;
    final totalEarned =
        await watchTotalAmount(dateRange: range, type: TransactionType.income)
            .first;

    return FinancialDataPoint(
        range, (totalSpent ?? 0).abs(), (totalEarned ?? 0).abs());
  }

  Future<List<FinancialDataPoint>> getAggregatedRangeData(
      DateTimeRange range, AggregationLevel aggregationLevel) async {
    List<FinancialDataPoint> points = [];

    DateTime start = range.start;
    DateTime end = range.end;

    switch (aggregationLevel) {
      case AggregationLevel.daily:
        for (int i = 0; i < range.duration.inDays; i++) {
          final day = range.start.add(Duration(days: i));

          points.add(await getPointFromRange(
              DateTimeRange(start: day, end: day).makeInclusive()));
        }
        break;
      case AggregationLevel.weekly:
        while (start.isBefore(end)) {
          final DateTime chunkEnd =
              DateTime(start.year, start.month, start.day + 7);

          // To make sure the end date doesn't summarize beyond the specified
          // date range. Though, that behavior may be preferable for data uniformity.
          final DateTime actualEnd = chunkEnd.isAfter(end) ? end : chunkEnd;

          points.add(await getPointFromRange(
              DateTimeRange(start: start, end: actualEnd).makeInclusive()));
          start = chunkEnd.add(
              const Duration(days: 1)); // To start the new chunk at a new spot
        }
      case _:
        while (start.isBefore(end)) {
          final DateTime chunkEnd =
              DateTime(start.year, start.month + 1, 0, 23, 59, 59, 999);

          final DateTime actualEnd = chunkEnd.isAfter(end) ? end : chunkEnd;
          points.add(await getPointFromRange(
              DateTimeRange(start: start, end: actualEnd).makeInclusive()));

          start = chunkEnd.add(Duration(days: 1));
        }
    }

    return points;
  }

  // Handle it through updatePartialTransaction so it can work the correct way
  // with PowerSync
  Future<void> markTransactionsAsDeleted(List<String> ids) async {
    var query = update(transactions)
      ..where((t) => t.id.isIn(ids))
      ..write(const TransactionsCompanion(isDeleted: Value(true)));

    await db.executeQuery(query.constructQuery());
  }

  Future<void> markCategoryAsDeleted(String id) => db.updatePartialCategory(
      CategoriesCompanion(id: Value(id), isDeleted: const Value(true)));

  Future<void> unmarkTransactionsAsDeleted(List<String> ids) async {
    var query = update(transactions)
      ..where((t) => t.id.isIn(ids))
      ..write(const TransactionsCompanion(isDeleted: Value(false)));

    await db.executeQuery(query.constructQuery());
  }

  Future<void> unmarkCategoryAsDeleted(String id) => db.updatePartialCategory(
      CategoriesCompanion(id: Value(id), isDeleted: const Value(false)));

  Future<void> permanentlyDeleteTransactions(List<String> ids) async {
    var query = delete(transactions)..where((t) => t.id.isIn(ids));

    await db.executeQuery(query.constructQuery());
  }

  Future<void> permanentlyDeleteCategory(String id) =>
      db.deleteCategoryById(id);
}

@DriftDatabase(
    tables: [Categories, Transactions, Goals, Accounts], daos: [TransactionDao])
class AppDatabase extends _$AppDatabase {
  PowerSyncDatabase db;

  AppDatabase(this.db) : super(SqliteAsyncDriftConnection(db));

  @override
  int get schemaVersion => 1;

  Stream<List<Category>> watchCategories() => (select(categories)
        ..where(
          (tbl) => tbl.isDeleted.isNotValue(true),
        ))
      .watch();

  List<dynamic> convertVariables(List<dynamic> variables) =>
      variables.map((v) => v.value).toList();

  Future<void> executeQuery(GenerationContext query) async {
    final args = convertVariables(query.introducedVariables);

    await db.writeTransaction((tx) => tx.execute(query.sql, args));
  }

  // Transaction methods
  Future<Transaction> createTransaction(TransactionsCompanion entry) async {
    // Generate the SQL with Drift, then write the SQL to the database.
    final id = entry.id.present ? entry.id.value : uuid.v4();
    // 2. Create a companion that definitely includes the ID
    final entryWithId = entry.copyWith(id: Value(id));

    final statement =
        into(transactions).createContext(entryWithId, InsertMode.insert);

    await db.writeTransaction(
        (tx) => tx.execute(statement.sql, statement.boundVariables));

    var transaction = await getTransactionById(id);

    return transaction;
  }

  Future<void> updateTransaction(Transaction entry) async {
    final query = (update(transactions)..replace(entry)).constructQuery();

    await executeQuery(query);
  }

  Future<Transaction> updatePartialTransaction(
      TransactionsCompanion entry) async {
    final query = (update(transactions)
          ..where((t) => t.id.equals(entry.id.value))
          ..write(entry))
        .constructQuery();

    await executeQuery(query);

    return await getTransactionById(entry.id.value);
  }

  Future<void> deleteTransaction(Transaction entry) async {
    final query = (delete(transactions)..delete(entry)).constructQuery();

    await executeQuery(query);
  }

  Future<void> deleteTransactionById(String id) async {
    final query =
        (delete(transactions)..where((t) => t.id.equals(id))).constructQuery();

    await executeQuery(query);
  }

  Future<Transaction> getTransactionById(String id) => (select(transactions)
        ..where(
          (tbl) => tbl.id.equals(id),
        ))
      .getSingle();

  Future<Category> getCategoryById(String id) =>
      (select(categories)..where((tbl) => tbl.id.equals(id))).getSingle();

  // Category methods
  Future<Category> createCategory(CategoriesCompanion entry) async {
    final id = entry.id.present ? entry.id.value : uuid.v4();
    // 2. Create a companion that definitely includes the ID
    final entryWithId = entry.copyWith(id: Value(id));

    final statement =
        into(categories).createContext(entryWithId, InsertMode.insert);

    await db.writeTransaction((tx) async {
      await tx.execute(statement.sql, statement.boundVariables);
    });

    var category = await getCategoryById(id);

    return category;
  }

  Future<void> updateCategory(Category entry) async {
    final query = (update(categories)..replace(entry)).constructQuery();

    await executeQuery(query);
  }

  Future<Category> updatePartialCategory(CategoriesCompanion entry) async {
    final query = (update(categories)
          ..where((t) => t.id.equals(entry.id.value))
          ..write(entry))
        .constructQuery();

    await executeQuery(query);

    return await getCategoryById(entry.id.value);
  }

  Future<void> deleteCategory(Category entry) async {
    final query = (delete(categories)..delete(entry)).constructQuery();

    await executeQuery(query);
  }

  Future<void> deleteCategoryById(String id) async {
    final query =
        (delete(categories)..where((c) => c.id.equals(id))).constructQuery();

    await executeQuery(query);
  }
}
