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

class EnumIndexConverter<T extends Enum> extends TypeConverter<T, int> {
  final List<T> values;

  const EnumIndexConverter(this.values);

  @override
  T fromSql(int fromDb) => values[fromDb];

  @override
  int toSql(T value) => value.index;
}

class Transactions extends Table {
  @override
  String get tableName => "transactions";

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  IntColumn get type =>
      integer().map(const EnumIndexConverter(TransactionType.values))();

  TextColumn get category =>
      text().nullable().named('category_id').references(Categories, #id)();
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

  IntColumn get resetIncrement => integer()
      .withDefault(const Constant(0))
      .named('reset_increment')
      .map(const EnumIndexConverter(CategoryResetIncrement.values))();
  BoolColumn get allowNegatives =>
      boolean().withDefault(const Constant(false)).named('allow_negatives')();
  IntColumn get color =>
      integer().clientDefault(genColor).map(const ColorConverter())();
  RealColumn get balance => real().nullable()();
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

  Future<int> deleteTransaction(Transaction entry) =>
      delete(transactions).delete(entry);

  // Category methods
  Future<Category> createCategory(CategoriesCompanion entry) =>
      into(categories).insertReturning(entry);

  Future<bool> updateCategory(Category entry) =>
      update(categories).replace(entry);

  Future<int> deleteCategory(Category entry) =>
      delete(categories).delete(entry);
}
