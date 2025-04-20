import 'dart:math';

import 'package:budget/tools/enums.dart';
import 'package:budget/tools/filters.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color, DateTimeRange;
import 'package:intl/intl.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase, uuid;
import 'package:drift_sqlite_async/drift_sqlite_async.dart';

part 'app_database.g.dart';

int genColor() =>
    Color((Random().nextDouble() * 0xFFFFFF).toInt()).withAlpha(255).toARGB32();

class Transactions extends Table {
  @override
  String get tableName => "transactions";

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  IntColumn get type => intEnum<TransactionType>()();

  TextColumn get category => text()
      .nullable()
      .named('category_id')
      .references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get notes => text().nullable()();
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

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(AppDatabase db) : super(db);

  Stream<List<Transaction>> watchTransactionsPage({
    List<TransactionFilter>? filters,
    Sort? sort,
    int limit = 20,
    int? offset,
  }) {
    var query = db.select(db.transactions);

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
                t.date.isBiggerOrEqualValue(f.value.start) &
                t.date.isSmallerOrEqualValue(f.value.end));
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
              })
        ]);
    } else {
      query = query..orderBy([(t) => OrderingTerm.desc(t.date)]);
    }

    query = query..limit(limit, offset: offset);

    return query.watch();
  }

  Future<double> getTotalAmount({
    TransactionType? type,
    DateTimeRange? dateRange,
    Category? category,
  }) async {
    var query = select(transactions);

    if (type != null) {
      query = query..where((t) => t.type.equalsValue(type));
    }

    if (category != null) {
      query = query..where((t) => t.category.equals(category.id));
    }

    if (dateRange != null) {
      query = query
        ..where((t) => t.date.isBetweenValues(dateRange.start, dateRange.end));
    }

    return await query
            .addColumns([transactions.amount])
            .map((row) => row.read(transactions.amount))
            .getSingle() ??
        0;
  }
}

@DriftDatabase(tables: [Categories, Transactions], daos: [TransactionDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(PowerSyncDatabase db) : super(SqliteAsyncDriftConnection(db));

  @override
  int get schemaVersion => 1;

  Stream<List<Category>> watchCategories() => select(categories).watch();

  // Transaction methods
  Future<Transaction> createTransaction(TransactionsCompanion entry) =>
      into(transactions).insertReturning(entry);

  Future<bool> updateTransaction(Transaction entry) =>
      update(transactions).replace(entry);

  Future<bool> updatePartialTransaction(TransactionsCompanion entry) async {
    int value = await (update(transactions)
          ..where((t) => t.id.equals(entry.id.value)))
        .write(entry);

    return value != 0;
  }

  Future<int> deleteTransaction(Transaction entry) =>
      delete(transactions).delete(entry);

  Future<Transaction> getTransactionById(String id) => (select(transactions)
        ..where(
          (tbl) => tbl.id.equals(id),
        ))
      .getSingle();

  Future<Category> getCategoryById(String id) =>
      (select(categories)..where((tbl) => tbl.id.equals(id))).getSingle();

  // Category methods
  Future<Category> createCategory(CategoriesCompanion entry) =>
      into(categories).insertReturning(entry);

  Future<bool> updateCategory(Category entry) =>
      update(categories).replace(entry);

  Future<Category?> updatePartialCategory(CategoriesCompanion entry) async {
    int value = await (update(categories)
          ..where((c) => c.id.equals(entry.id.value)))
        .write(entry);

    if (value != 1) {
      // TODO: LOG THIS
      return null;
    }

    return (select(categories)..where((c) => c.id.equals(entry.id.value)))
        .getSingle();
  }

  Future<int> deleteCategory(Category entry) =>
      delete(categories).delete(entry);
}
