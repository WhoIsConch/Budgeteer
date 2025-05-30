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

mixin SoftDeletableTable on Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();
  BoolColumn get isDeleted =>
      boolean().clientDefault(() => false).named('is_deleted')();
  BoolColumn get isArchived =>
      boolean().clientDefault(() => false).named('is_archived')();
}

class Transactions extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get date => text().map(const DateTextConverter())();
  TextColumn get createdAt =>
      text()
          .map(const DateTimeTextConverter())
          .clientDefault(() => DateTime.now().toIso8601String())
          .named('created_at')();
  IntColumn get type => intEnum<TransactionType>()();
  BoolColumn get isDeleted =>
      boolean().clientDefault(() => false).named('is_deleted')();
  BoolColumn get isArchived =>
      boolean().clientDefault(() => false).named('is_archived')();
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

class Categories extends Table with SoftDeletableTable {
  @override
  String get tableName => 'categories';

  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();

  IntColumn get resetIncrement =>
      intEnum<CategoryResetIncrement>()
          .withDefault(const Constant(0))
          .named('reset_increment')();
  BoolColumn get allowNegatives =>
      boolean().clientDefault(() => false).named('allow_negatives')();
  IntColumn get color =>
      integer().clientDefault(genColor).map(const ColorConverter())();
  RealColumn get balance => real().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Accounts extends Table with SoftDeletableTable {
  @override
  get tableName => 'accounts';

  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get priority => integer().nullable().unique()();

  IntColumn get color =>
      integer().clientDefault(genColor).map(const ColorConverter())();
}

class Goals extends Table with SoftDeletableTable {
  @override
  get tableName => 'goals';

  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  RealColumn get cost => real()();

  IntColumn get color =>
      integer().clientDefault(genColor).map(const ColorConverter())();
  TextColumn get dueDate =>
      text().nullable().named('due_date').map(const DateTextConverter())();
}

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  Future<bool> isPriorityTaken(int newPriority, {String? currentItemId}) async {
    /// Ensure that a priority field for an account isn't taken.
    final query = select(accounts)
      ..where((a) => a.priority.equals(newPriority));

    if (currentItemId != null) {
      // If an item is being updated, it shouldn't check itself
      query.where((a) => a.id.equals(currentItemId).not());
    }

    final existingItems = await query.get();
    return existingItems.isNotEmpty;
  }

  Stream<List<AccountWithTotal>> watchAccounts({
    List<Filter>? filters,
    includeArchived = false,
    sortDescending = true,
    net = true,
  }) {
    final queryWithSum = db.getCombinedQuery(
      accounts,
      includeArchived: includeArchived,
      net: net,
    );

    if (filters != null) {
      queryWithSum.query.where(filters.buildWhereClause(db.transactions));
    }

    return queryWithSum.query.watch().map((rows) {
      final List<AccountWithTotal> accountsWithTotals =
          rows.map((row) {
            final account = row.readTable(accounts);
            final total = row.read<double>(queryWithSum.sum);

            return AccountWithTotal(account: account, total: total ?? 0);
          }).toList();

      accountsWithTotals.sort((a, b) {
        if (a.account.priority != null && b.account.priority == null) {
          return -1;
        } else if (a.account.priority == null && b.account.priority != null) {
          return 1;
        } else if (a.account.priority == null && b.account.priority == null) {
          return 0;
        }

        if (sortDescending) {
          return b.account.priority!.compareTo(a.account.priority!);
        } else {
          return a.account.priority!.compareTo(b.account.priority!);
        }
      });

      return accountsWithTotals;
    });
  }

  Stream<AccountWithTotal> watchAccountById(
    String id, {
    bool includeArchived = true,
  }) {
    final queryWithSum = db.getCombinedQuery(
      accounts,
      includeArchived: includeArchived,
    );
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
    final queryWithSum = db.getCombinedQuery(
      accounts,
      includeArchived: includeArchived,
    );
    final filteredQuery = queryWithSum.query..where(accounts.id.equals(id));

    final mappedSelectable = filteredQuery.map((row) {
      final account = row.readTable(accounts);
      final total = row.read<double>(queryWithSum.sum) ?? 0;

      return AccountWithTotal(account: account, total: total);
    });

    return mappedSelectable.getSingle();
  }

  Future<Account> createAccount(AccountsCompanion entry) async {
    if (entry.priority.value != null) {
      bool isTaken = await isPriorityTaken(entry.priority.value!);

      if (isTaken) {
        throw ArgumentError(
          'Account with priority ${entry.priority.value} already exists',
        );
      }
    }
    final id = entry.id.present ? entry.id.value : uuid.v4();

    final entryWithId = entry.copyWith(id: Value(id));
    final account = into(accounts).insertReturning(entryWithId);

    return account;
  }

  Future<Account> updateAccount(AccountsCompanion entry) async {
    assert(entry.id.present, '`id` must be supplied when updating an Account');

    if (entry.priority.value != null) {
      bool isTaken = await isPriorityTaken(
        entry.priority.value!,
        currentItemId: entry.id.value,
      );

      if (isTaken) {
        throw ArgumentError(
          'Account with priority ${entry.priority.value} already exists',
        );
      }
    }

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

  Stream<List<GoalWithAchievedAmount>> watchGoals({
    List<Filter>? filters,
    bool includeFinished = true,
    bool sortDescending = true,
    bool net = true,
  }) {
    final queryWithSum = db.getCombinedQuery(
      goals,
      includeArchived: includeFinished,
      net: net,
    );

    if (filters != null) {
      queryWithSum.query.where(filters.buildWhereClause(db.transactions));
    }

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
    )).write(GoalsCompanion(isArchived: Value(status)));

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
    final queryWithSum = db.getCombinedQuery(
      goals,
      includeArchived: includeFinished,
    );

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
    final queryWithSum = db.getCombinedQuery(
      goals,
      includeArchived: includeFinished,
    );

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
    List<Filter>? filters,
    Sort? sort,
    int? limit,
    int? offset,
    bool showArchived = false,
  }) {
    var query = db.select(db.transactions)..where((t) => t.isDeleted.not());

    if (!showArchived) {
      query = query..where((t) => t.isArchived.not());
    }

    if (filters != null) query.where((t) => filters.buildWhereClause(t));

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
            (t) => OrderingTerm(mode: sortMode, expression: t.createdAt),
          ]);
    } else {
      query =
          query..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt),
          ]);
    }

    if (limit != null) {
      query = query..limit(limit, offset: offset);
    }

    return query.watch();
  }

  Stream<double?> watchTotalAmount({
    List<Filter>? filters,
    bool nullCategory = false, // TODO: Integrate these with filters
    bool nullAccount = false,
    bool nullGoal = false,
    bool net = true,
  }) {
    var query = select(transactions)
      ..where((t) => t.isDeleted.not() & t.isArchived.not());

    if (filters != null) query.where((t) => filters.buildWhereClause(t));

    if (nullCategory) {
      query.where((t) => t.category.isNull());
    }

    if (nullGoal) {
      query.where((t) => t.goalId.isNull());
    }

    if (nullAccount) {
      query.where((t) => t.accountId.isNull());
    }
    final sumQuery = db.getSignedTransactionSumQuery();

    final type = filters?.whereType<TypeFilter>();

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
          filters: [
            DateRangeFilter(range),
            TypeFilter(TransactionType.expense),
          ],
        ).first;
    final totalEarned =
        await watchTotalAmount(
          filters: [DateRangeFilter(range), TypeFilter(TransactionType.income)],
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
        // +1 to ensure the duration includes today's activities
        for (int i = 0; i < range.duration.inDays + 1; i++) {
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
              DateTimeRange(start: start, end: actualEnd),
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

  QueryWithSum _getCategoriesWithAmountsQuery() {
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

  QueryWithSum _getQueryWithSum({
    bool includeArchived = false,
    bool net = true,
    bool sumByResetIncrement = true,
  }) {
    QueryWithSum queryWithSum;

    if (sumByResetIncrement) {
      queryWithSum = _getCategoriesWithAmountsQuery();
    } else {
      queryWithSum = db.getCombinedQuery(
        categories,
        includeArchived: includeArchived,
        net: net,
      );
    }

    return queryWithSum;
  }

  Stream<List<CategoryWithAmount>> watchCategories({
    List<Filter>? filters,
    bool includeArchived = false,
    bool net = true,
    bool sumByResetIncrement = true,
  }) {
    final queryWithSum = _getQueryWithSum(
      includeArchived: includeArchived,
      net: net,
      sumByResetIncrement: sumByResetIncrement,
    );

    if (filters != null) {
      queryWithSum.query.where(filters.buildWhereClause(db.transactions));
    }

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

  Future<CategoryWithAmount?> getCategoryById(
    String id, {
    bool includeArchived = false,
    bool net = true,
    bool sumByResetIncrement = true,
  }) async {
    final queryWithSum = _getQueryWithSum(
      includeArchived: includeArchived,
      net: net,
      sumByResetIncrement: sumByResetIncrement,
    );

    final singleCategoryQuery =
        queryWithSum.query..where(categories.id.equals(id));

    final row = await singleCategoryQuery.getSingleOrNull();

    if (row != null) {
      final category = row.readTable(categories);
      final amount = row.read<double>(queryWithSum.sum);

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

  QueryWithSum getCombinedQuery<T extends SoftDeletableTable>(
    TableInfo<T, dynamic> relatedTable, {
    bool includeArchived = false,
    bool net = true,
  }) {
    var query = select(
      relatedTable,
    ).join([leftOuterJoin(transactions, _getJoinCondition(relatedTable))]);

    query.where(relatedTable.asDslTable.isDeleted.not());

    if (!includeArchived) {
      query.where(relatedTable.asDslTable.isArchived.not());
    }

    Expression<double> sumExpression;

    if (net) {
      sumExpression = getSignedTransactionSumQuery();
    } else {
      sumExpression = transactions.amount.sum();
    }

    query.addColumns([sumExpression]);
    query.groupBy([relatedTable.asDslTable.id]);

    return QueryWithSum(query, sumExpression);
  }

  Expression<bool> _getJoinCondition<T extends Table>(
    TableInfo<T, dynamic> table,
  ) {
    switch (table.actualTableName) {
      case 'categories':
        return transactions.category.equalsExp(categories.id);
      case 'accounts':
        return transactions.accountId.equalsExp(accounts.id);
      case 'goals':
        return transactions.goalId.equalsExp(goals.id);
      default:
        throw ArgumentError('Unsupported table: ${table.actualTableName}');
    }
  }

  Expression<double> getSignedTransactionSumQuery({
    bool includeArchived = false,
    bool summed = true,
  }) {
    // Mainly uses "summed" for backwards compatibility with code I wrote less
    // than an hour ago
    List<CaseWhen<bool, double>> cases;

    if (includeArchived) {
      cases = [
        CaseWhen(
          transactions.type.equalsValue(TransactionType.income) &
              transactions.isDeleted.not(),
          then: transactions.amount,
        ),
        CaseWhen(
          transactions.type.equalsValue(TransactionType.expense) &
              transactions.isDeleted.not(),
          then: -transactions.amount,
        ),
      ];
    } else {
      cases = [
        CaseWhen(
          transactions.type.equalsValue(TransactionType.income) &
              transactions.isDeleted.not() &
              transactions.isArchived.not(),
          then: transactions.amount,
        ),
        CaseWhen(
          transactions.type.equalsValue(TransactionType.expense) &
              transactions.isDeleted.not() &
              transactions.isArchived.not(),
          then: -transactions.amount,
        ),
      ];
    }

    final expression = CaseWhenExpression(
      cases: cases,
      orElse: const Constant(0.0),
    );
    if (summed) {
      return expression.sum();
    }
    return expression;
  }
}
