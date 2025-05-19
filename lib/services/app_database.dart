import 'package:budget/models/data.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/utils/tools.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color, DateTimeRange;
import 'package:powersync/powersync.dart' show PowerSyncDatabase, uuid;
import 'package:drift_sqlite_async/drift_sqlite_async.dart';

part 'app_database.g.dart';

class Transactions extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get date => text().map(const DateTextConverter())();
  IntColumn get type => intEnum<TransactionType>()();
  BoolColumn get isDeleted =>
      boolean()
          .nullable()
          .withDefault(const Constant(false))
          .named('is_deleted')();
  BoolColumn get isArchived =>
      boolean()
          .nullable()
          .withDefault(const Constant(false))
          .named('is_archived')();
  TextColumn get notes => text().nullable()();

  TextColumn get category =>
      text()
          .nullable()
          .named('category_id')
          .references(Categories, #id, onDelete: KeyAction.setNull)();

  TextColumn get accountId =>
      text()
          .nullable()
          .named('account_id')
          .references(Accounts, #id, onDelete: KeyAction.setNull)();

  TextColumn get goalId =>
      text()
          .nullable()
          .named('goal_id')
          .references(Goals, #id, onDelete: KeyAction.setNull)();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Categories extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();

  IntColumn get resetIncrement =>
      intEnum<CategoryResetIncrement>()
          .withDefault(const Constant(0))
          .named('reset_increment')();
  BoolColumn get allowNegatives =>
      boolean().withDefault(const Constant(false)).named('allow_negatives')();
  IntColumn get color =>
      integer().clientDefault(genColor).map(const ColorConverter())();
  RealColumn get balance => real().nullable()();
  BoolColumn get isDeleted =>
      boolean()
          .nullable()
          .withDefault(const Constant(false))
          .named('is_deleted')();
  BoolColumn get isArchived =>
      boolean()
          .nullable()
          .withDefault(const Constant(false))
          .named('is_archived')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Accounts extends Table {
  @override
  get tableName => 'accounts';

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();

  IntColumn get color =>
      integer().clientDefault(genColor).map(const ColorConverter())();
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
  TextColumn get notes => text().nullable()();
  RealColumn get cost => real()();

  IntColumn get color =>
      integer().clientDefault(genColor).map(const ColorConverter())();
  TextColumn get dueDate =>
      text().nullable().named('due_date').map(const DateTextConverter())();
  BoolColumn get isFinished => // Basically isArchived
      boolean().withDefault(const Constant(false)).named('is_finished')();
  BoolColumn get isDeleted =>
      boolean().withDefault(const Constant(false)).named('is_deleted')();
}

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  QueryWithSum _getCombinedQuery({bool includeArchived = false}) {
    var query = select(accounts).join([
      leftOuterJoin(
        db.transactions,
        db.transactions.accountId.equalsExp(accounts.id),
      ),
    ]);

    final signedSumQuery = db.getSignedTransactionSumQuery();

    if (!includeArchived) {
      query =
          query..where(
            accounts.isArchived.isNotExp(const Constant(true)) &
                db.transactions.isDeleted.isNotExp(
                  const Constant(true) &
                      db.transactions.isArchived.isNotExp(const Constant(true)),
                ),
          );
    }

    query =
        query
          ..where(accounts.isDeleted.equals(false))
          ..addColumns([signedSumQuery])
          ..groupBy([accounts.id]);

    return QueryWithSum(query, signedSumQuery);
  }

  Stream<List<AccountWithTotal>> watchAccounts({
    includeArchived = false,
    sortDescending = true,
  }) {
    final queryWithSum = _getCombinedQuery(includeArchived: includeArchived);

    return queryWithSum.query.watch().map((rows) {
      final List<AccountWithTotal> accountsWithTotals =
          rows.map((row) {
            final account = row.readTable(accounts);
            final total = row.read<double>(queryWithSum.sum);

            return AccountWithTotal(account: account, total: total ?? 0);
          }).toList();

      accountsWithTotals.sort((a, b) {
        if (sortDescending) {
          return b.total.compareTo(a.total);
        } else {
          return a.total.compareTo(b.total);
        }
      });

      return accountsWithTotals;
    });
  }

  Stream<AccountWithTotal> watchAccountById(
    String id, {
    bool includeArchived = true,
  }) {
    final queryWithSum = _getCombinedQuery(includeArchived: includeArchived);
    final filteredQuery = queryWithSum.query..where(accounts.id.equals(id));

    final mappedSelectable = filteredQuery.map((row) {
      final account = row.readTable(accounts);
      final total = row.read<double>(queryWithSum.sum) ?? 0;

      return AccountWithTotal(account: account, total: total);
    });

    return mappedSelectable.watchSingle();
  }

  Future<AccountWithTotal> getAccountById(
    String id, {
    bool includeArchived = true,
  }) {
    final queryWithSum = _getCombinedQuery(includeArchived: includeArchived);
    final filteredQuery = queryWithSum.query..where(accounts.id.equals(id));

    final mappedSelectable = filteredQuery.map((row) {
      final account = row.readTable(accounts);
      final total = row.read<double>(queryWithSum.sum) ?? 0;

      return AccountWithTotal(account: account, total: total);
    });

    return mappedSelectable.getSingle();
  }

  Future<Account> createAccount(AccountsCompanion entry) async {
    final id = entry.id.present ? entry.id.value : uuid.v4();

    final entryWithId = entry.copyWith(id: Value(id));
    final account = into(accounts).insertReturning(entryWithId);

    return account;
  }

  Future<Account> updateAccount(AccountsCompanion entry) async {
    assert(entry.id.present, '`id` must be supplied when updating an Account');

    final account = await (update(accounts)
      ..where((a) => a.id.equals(entry.id.value))).writeReturning(entry);

    return account.single;
  }

  Future<int> setAccountsDeleted(List<String> ids, bool status) =>
      (update(accounts)..where(
        (a) => a.id.isIn(ids),
      )).write(AccountsCompanion(isDeleted: Value(status)));

  Future<int> setAccountsArchived(List<String> ids, bool status) =>
      (update(accounts)..where(
        (a) => a.id.isIn(ids),
      )).write(AccountsCompanion(isArchived: Value(status)));

  Future<int> permanentlyDeleteAccounts(List<String> ids) =>
      (delete(accounts)..where((a) => a.id.isIn(ids))).go();
}

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  QueryWithSum _getCombinedQuery({bool includeFinished = false}) {
    var query = select(goals).join([
      leftOuterJoin(
        db.transactions,
        db.transactions.goalId.equalsExp(goals.id),
      ),
    ]);

    final signedSumQuery = db.getSignedTransactionSumQuery();

    if (!includeFinished) {
      query = query..where(goals.isFinished.isNotExp(const Constant(true)));
    }

    query =
        query
          ..where(goals.isDeleted.equals(false))
          ..addColumns([signedSumQuery])
          ..groupBy([goals.id]);

    return QueryWithSum(query, signedSumQuery);
  }

  Stream<List<GoalWithAchievedAmount>> watchGoals({
    bool includeFinished = true,
    bool sortDescending = true,
  }) {
    final queryWithSum = _getCombinedQuery(includeFinished: includeFinished);

    // View all of the goals in the database
    return queryWithSum.query.watch().map((rows) {
      final List<GoalWithAchievedAmount> goalsWithAmounts =
          rows.map((row) {
            final goal = row.readTable(goals);
            final achievedAmount = row.read<double>(queryWithSum.sum) ?? 0.0;

            return GoalWithAchievedAmount(
              goal: goal,
              achievedAmount: achievedAmount,
            );
          }).toList();

      goalsWithAmounts.sort((a, b) {
        final double percentageA = a.calculatePercentage();
        final double percentageB = b.calculatePercentage();

        if (sortDescending) {
          return percentageB.compareTo(percentageA);
        } else {
          return percentageA.compareTo(percentageB);
        }
      });

      return goalsWithAmounts;
    });
  }

  Stream<double?> getGoalFulfillmentAmount(Goal goal) {
    var query = db.select(db.transactions)..where(
      (t) =>
          t.goalId.equals(goal.id) &
          t.isDeleted.equals(true).not() &
          t.isArchived.equals(true).not(),
    );

    final signedSumQuery = db.getSignedTransactionSumQuery();

    return query
        .addColumns([signedSumQuery])
        .map((row) => row.read(signedSumQuery))
        .watchSingle();
  }

  Future<void> setGoalsDeleted(List<String> ids, bool status) => (update(goals)
    ..where(
      (g) => g.id.isIn(ids),
    )).write(GoalsCompanion(isDeleted: Value(status)));

  Future<void> setGoalsFinished(List<String> ids, bool status) => (update(goals)
    ..where(
      (g) => g.id.isIn(ids),
    )).write(GoalsCompanion(isFinished: Value(status)));

  Future<int> permanentlyDeleteGoals(List<String> ids) =>
      (delete(goals)..where((g) => g.id.isIn(ids))).go();

  Future<Goal> createGoal(GoalsCompanion entry) async {
    // Generate the SQL with Drift, then write the SQL to the database.
    final id = entry.id.present ? entry.id.value : uuid.v4();
    // 2. Create a companion that definitely includes the ID
    final entryWithId = entry.copyWith(id: Value(id));

    final goal = into(goals).insertReturning(entryWithId);

    return goal;
  }

  Future<GoalWithAchievedAmount> getGoalById(
    String id, {
    bool includeFinished = true,
  }) {
    final queryWithSum = _getCombinedQuery(includeFinished: includeFinished);

    final filteredQuery = queryWithSum.query..where(goals.id.equals(id));

    final mappedSelectable = filteredQuery.map((row) {
      final goal = row.readTable(goals);
      final achievedAmount = row.read<double>(queryWithSum.sum) ?? 0;

      return GoalWithAchievedAmount(goal: goal, achievedAmount: achievedAmount);
    });

    return mappedSelectable.getSingle();
  }

  Stream<GoalWithAchievedAmount> watchGoalById(
    String id, {
    bool includeFinished = true,
  }) {
    final queryWithSum = _getCombinedQuery(includeFinished: includeFinished);

    final filteredQuery = queryWithSum.query..where(goals.id.equals(id));

    final mappedSelectable = filteredQuery.map((row) {
      final goal = row.readTable(goals);
      final achievedAmount = row.read<double>(queryWithSum.sum) ?? 0;

      return GoalWithAchievedAmount(goal: goal, achievedAmount: achievedAmount);
    });

    return mappedSelectable.watchSingle();
  }

  Future<Goal> updateGoal(GoalsCompanion entry) async {
    assert(entry.id.present, '`id` must be supplied when updating a Goal');

    final goal = await (update(goals)
      ..where((g) => g.id.equals(entry.id.value))).writeReturning(entry);

    return goal.single;
  }
}

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Stream<List<Transaction>> watchTransactionsPage({
    List<TransactionFilter>? filters,
    Sort? sort,
    int? limit,
    int? offset,
    bool showArchived = false,
  }) {
    var query = db.select(db.transactions)
      ..where((t) => t.isDeleted.isNotExp(const Constant(true)));

    if (!showArchived) {
      query = query..where((t) => t.isArchived.isNotExp(const Constant(true)));
    }

    filters ??= [];

    for (final TransactionFilter filter in filters) {
      switch (filter) {
        case TransactionFilter<AmountFilter> f:
          switch (f.value.type!) {
            case AmountFilterType.greaterThan:
              query =
                  query
                    ..where((t) => t.amount.isBiggerThanValue(f.value.amount!));
              break;
            case AmountFilterType.lessThan:
              query =
                  query..where(
                    (t) => t.amount.isSmallerThanValue(f.value.amount!),
                  );
              break;
            case AmountFilterType.exactly:
              query = query..where((t) => t.amount.equals(f.value.amount!));
              break;
          }
          break;
        case TransactionFilter<String> f:
          // TODO: Figure out if this can be converted to partial text search
          query =
              query..where(
                (t) =>
                    t.title.lower().equals(f.value.toLowerCase()) |
                    t.notes.lower().equals(f.value.toLowerCase()),
              );
          break;
        case TransactionFilter<DateTimeRange> f:
          query =
              query..where(
                (t) =>
                    t.date.isBiggerOrEqualValue(
                      formatter.format(f.value.start),
                    ) &
                    t.date.isSmallerOrEqualValue(formatter.format(f.value.end)),
              );
          break;
        case TransactionFilter<TransactionType> f:
          query = query..where((t) => t.type.equals(f.value.value));
          break;
        case TransactionFilter<List<CategoryWithAmount>> f:
          query =
              query..where(
                (t) => t.category.isIn(f.value.map((e) => e.category.id)),
              );
          break;
      }
    }

    if (sort != null) {
      OrderingMode sortMode =
          sort.sortOrder == SortOrder.ascending
              ? OrderingMode.asc
              : OrderingMode.desc;

      query =
          query..orderBy([
            (t) => OrderingTerm(
              mode: sortMode,
              expression:
                  switch (sort.sortType) {
                        SortType.amount => t.amount,
                        SortType.date => t.date,
                        SortType.title => t.title,
                      }
                      as Expression<Object>,
            ),
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
    // Unfortunately, we need to use isNotExp(Constant(true)) since these fields are
    // nullable. This is because something (either Supabase, Drift, or PowerSync)
    // doesn't think transactions are capable of handling non-null booleans.
    // My money is on PowerSync being the issue.
    var query = select(transactions)..where(
      (t) =>
          t.isDeleted.isNotExp(const Constant(true)) &
          t.isArchived.isNotExp(const Constant(true)),
    );

    if (type != null) {
      query = query..where((t) => t.type.equalsValue(type));
    }

    if (category != null) {
      query = query..where((t) => t.category.equals(category.id));
    } else if (nullCategory) {
      query = query..where((t) => t.category.isNull());
    }

    if (dateRange != null) {
      query =
          query..where(
            (t) => t.date.isBetweenValues(
              formatter.format(dateRange.start),
              formatter.format(dateRange.end),
            ),
          );
    }

    final sumQuery = db.getSignedTransactionSumQuery();

    if (type == null && net) {
      // If the type is null, we want to get the net amount
      return query
          .addColumns([sumQuery])
          .map((row) => row.read(sumQuery))
          .watchSingle();
    }

    return query
        .addColumns([transactions.amount.sum()])
        .map((row) => row.read(transactions.amount.sum()))
        .watchSingle();
  }

  Future<HydratedTransaction> hydrateTransaction(
    Transaction transaction,
  ) async {
    // TODO: Optimize this
    GoalWithAchievedAmount? goal;
    CategoryWithAmount? category;
    AccountWithTotal? account;

    if (transaction.goalId != null) {
      goal = await db.goalDao.getGoalById(transaction.goalId!);
    }

    if (transaction.category != null) {
      category = await db.categoryDao.getCategoryById(transaction.category!);
    }

    if (transaction.accountId != null) {
      account =
          await db.accountDao.watchAccountById(transaction.accountId!).first;
    }

    return HydratedTransaction(
      transaction: transaction,
      goalPair: goal,
      categoryPair: category,
      accountPair: account,
    );
  }

  Future<FinancialDataPoint> getPointFromRange(DateTimeRange range) async {
    final totalSpent =
        await watchTotalAmount(
          dateRange: range,
          type: TransactionType.expense,
        ).first;
    final totalEarned =
        await watchTotalAmount(
          dateRange: range,
          type: TransactionType.income,
        ).first;

    return FinancialDataPoint(
      range,
      (totalSpent ?? 0).abs(),
      (totalEarned ?? 0).abs(),
    );
  }

  Future<List<FinancialDataPoint>> getAggregatedRangeData(
    DateTimeRange range,
    AggregationLevel aggregationLevel,
  ) async {
    List<FinancialDataPoint> points = [];

    DateTime start = range.start;
    DateTime end = range.end;

    switch (aggregationLevel) {
      case AggregationLevel.daily:
        for (int i = 0; i < range.duration.inDays; i++) {
          final day = range.start.add(Duration(days: i));

          points.add(
            await getPointFromRange(
              DateTimeRange(start: day, end: day).makeInclusive(),
            ),
          );
        }
        break;
      case AggregationLevel.weekly:
        while (start.isBefore(end)) {
          final DateTime chunkEnd = DateTime(
            start.year,
            start.month,
            start.day + 7,
          );

          // To make sure the end date doesn't summarize beyond the specified
          // date range. Though, that behavior may be preferable for data uniformity.
          final DateTime actualEnd = chunkEnd.isAfter(end) ? end : chunkEnd;

          points.add(
            await getPointFromRange(
              DateTimeRange(start: start, end: actualEnd).makeInclusive(),
            ),
          );
          start = chunkEnd.add(
            const Duration(days: 1),
          ); // To start the new chunk at a new spot
        }
      case _:
        while (start.isBefore(end)) {
          final DateTime chunkEnd = DateTime(
            start.year,
            start.month + 1,
            0,
            23,
            59,
            59,
            999,
          );

          final DateTime actualEnd = chunkEnd.isAfter(end) ? end : chunkEnd;
          points.add(
            await getPointFromRange(
              DateTimeRange(start: start, end: actualEnd).makeInclusive(),
            ),
          );

          start = chunkEnd.add(Duration(days: 1));
        }
    }

    return points;
  }

  Future<int> setTransactionsArchived(List<String> ids, bool status) =>
      (update(transactions)..where(
        (t) => t.id.isIn(ids),
      )).write(TransactionsCompanion(isArchived: Value(status)));

  Future<int> setTransactionsDeleted(List<String> ids, bool status) =>
      (update(transactions)..where(
        (t) => t.id.isIn(ids),
      )).write(TransactionsCompanion(isDeleted: Value(status)));

  Future<int> permanentlyDeleteTransactions(List<String> ids) =>
      (delete(transactions)..where((t) => t.id.isIn(ids))).go();

  // Transaction methods
  Future<Transaction> createTransaction(TransactionsCompanion entry) async {
    // Generate the SQL with Drift, then write the SQL to the database.
    final id = entry.id.present ? entry.id.value : uuid.v4();
    // 2. Create a companion that definitely includes the ID
    final entryWithId = entry.copyWith(id: Value(id));

    final transaction = await into(transactions).insertReturning(entryWithId);

    return transaction;
  }

  Future<Transaction> updateTransaction(TransactionsCompanion entry) async {
    final query = update(transactions)
      ..where((t) => t.id.equals(entry.id.value));

    return (await query.writeReturning(entry)).single;
  }

  Future<Transaction> getTransactionById(String id) =>
      (select(transactions)..where((tbl) => tbl.id.equals(id))).getSingle();
}

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  CaseWhen<bool, String> _getCaseWhen(
    CategoryResetIncrement increment,
    bool isStart,
  ) {
    DateTimeRange timeRange =
        increment.relativeDateRange?.getRange() ??
        RelativeDateRange.today.getRange();

    return CaseWhen(
      categories.resetIncrement.equalsValue(increment),
      then: Constant<String>(
        formatter.format(isStart ? timeRange.start : timeRange.end),
      ),
    );
  }

  QueryWithSum getCategoriesWithAmountsQuery() {
    // Get the start and end date to look for the values
    Expression<String> startDate = CaseWhenExpression<String>(
      cases:
          CategoryResetIncrement.values
              .map((increment) => _getCaseWhen(increment, true))
              .toList(),
    );
    Expression<String> endDate = CaseWhenExpression<String>(
      cases:
          CategoryResetIncrement.values
              .map((increment) => _getCaseWhen(increment, false))
              .toList(),
    );

    // A filter to check if the date is between these ranges.
    final dateInRangeCondition = db.transactions.date.isBetween(
      startDate,
      endDate,
    );

    // A filter to sign the amount, since we always want the total amount in
    // a category to be the net value
    final signedAmount = db.getSignedTransactionSumQuery(summed: false);

    // The actual condition we're going to filter by. If the reset increment is
    // never, we can't filter by dates so we ensure the filter is always true,
    // or accepts all transactions that fulfill the rest of the conditions
    final sumFilterCondition = CaseWhenExpression(
      cases: [
        CaseWhen(
          categories.resetIncrement.equalsValue(CategoryResetIncrement.never),
          then: const Constant(true),
        ),
      ],
      orElse: dateInRangeCondition,
    );

    // Construct the actual expression to put in the query, used in case the
    // signed amount's sum returns null for some reason (which it never should)
    final conditionalSum = coalesce([
      signedAmount.sum(filter: sumFilterCondition),
      const Constant(0.0),
    ]);

    var query = select(categories).join([
      leftOuterJoin(
        db.transactions,
        db.transactions.category.equalsExp(categories.id),
      ),
    ]);

    // Also ensure the category isn't deleted or archived
    final queryWithSum =
        query
          ..where(
            categories.isDeleted.equals(false) &
                categories.isArchived.equals(false),
          )
          ..addColumns([conditionalSum])
          ..groupBy([categories.id]);

    return QueryWithSum(queryWithSum, conditionalSum);
  }

  Stream<List<CategoryWithAmount>> watchCategories() {
    final queryWithSum = getCategoriesWithAmountsQuery();

    return queryWithSum.query.watch().map(
      (rows) =>
          rows
              .map(
                (row) => CategoryWithAmount(
                  category: row.readTable(categories),
                  amount: row.read<double>(queryWithSum.sum),
                ),
              )
              .toList(),
    );
  }

  Future<CategoryWithAmount?> getCategoryById(String id) async {
    final categorySumQuery = getCategoriesWithAmountsQuery();

    final singleCategoryQuery =
        categorySumQuery.query..where(categories.id.equals(id));

    final row = await singleCategoryQuery.getSingleOrNull();

    if (row != null) {
      final category = row.readTable(categories);
      final amount = row.read<double>(categorySumQuery.sum);

      return CategoryWithAmount(category: category, amount: amount);
    } else {
      return null;
    }
  }

  Future<Category> createCategory(CategoriesCompanion entry) async {
    final id = entry.id.present ? entry.id.value : uuid.v4();
    // 2. Create a companion that definitely includes the ID
    final entryWithId = entry.copyWith(id: Value(id));

    final category = await into(categories).insertReturning(entryWithId);

    return category;
  }

  Future<Category> updateCategory(CategoriesCompanion entry) async {
    final query = update(categories)..where((t) => t.id.equals(entry.id.value));

    return (await query.writeReturning(entry)).single;
  }

  Future<int> setCategoriesArchived(List<String> ids, bool status) =>
      (update(categories)..where(
        (t) => t.id.isIn(ids),
      )).write(CategoriesCompanion(isArchived: Value(status)));

  Future<int> setCategoriesDeleted(List<String> ids, bool status) =>
      (update(categories)..where(
        (c) => c.id.isIn(ids),
      )).write(CategoriesCompanion(isDeleted: Value(status)));

  Future<int> permanentlyDeleteCategories(List<String> ids) =>
      (delete(categories)..where((c) => c.id.isIn(ids))).go();
}

@DriftDatabase(
  tables: [Categories, Transactions, Goals, Accounts],
  daos: [TransactionDao, GoalDao, AccountDao, CategoryDao],
)
class AppDatabase extends _$AppDatabase {
  PowerSyncDatabase db;

  AppDatabase(this.db) : super(SqliteAsyncDriftConnection(db));

  @override
  int get schemaVersion => 1;

  Expression<double> getSignedTransactionSumQuery({bool summed = true}) {
    // Mainly uses "summed" for backwards compatibility with code I wrote less
    // than an hour ago
    final expression = CaseWhenExpression(
      cases: [
        CaseWhen(
          transactions.type.equalsValue(TransactionType.income),
          then: transactions.amount,
        ),
        CaseWhen(
          transactions.type.equalsValue(TransactionType.expense),
          then: -transactions.amount,
        ),
      ],
      orElse: const Constant(0.0),
    );
    if (summed) {
      return expression.sum();
    }
    return expression;
  }
}
