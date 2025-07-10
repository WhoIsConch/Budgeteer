import 'package:budget/models/data.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/models/enums.dart';
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

  @override
  Set<Column<Object>>? get primaryKey => {id};
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

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.db);

  /// Get an [AccountWithAmount] from a [TypedResult] that contains the
  /// accounts table, expenses, and income queries.
  AccountWithAmount _buildAccountPair(TypedResult row, QueryWithSums query) {
    final account = row.readTable(accounts);
    final expenses = row.read<double>(query.expenses);
    final income = row.read<double>(query.income);

    return AccountWithAmount(
      account: account,
      income: income ?? 0,
      expenses: expenses ?? 0,
    );
  }

  /// Check whether the priority of an account is already used by another
  /// account.
  ///
  /// It isn't recommended to use this method often since it is an API call.
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

  /// Watch a list of accounts.
  Stream<List<AccountWithAmount>> watchAccounts({
    List<Filter>? filters,
    bool includeArchived = false,
    bool sortDescending = true,

    /// Show goals is optional since it may be useful in analytics, but for
    /// viewing balances you don't want to see the amount of money you put
    /// towards a goal. Any money put towards a goal can be considered spent.
    bool showGoals = false,
  }) {
    final queryWithSum = db._getCombinedQuery(
      accounts,
      includeArchived: includeArchived,
      showGoals: showGoals,
    );

    if (filters != null) {
      queryWithSum.query.where(filters.buildWhereClause(db.transactions));
    }

    return queryWithSum.query.watch().map((rows) {
      final accountsWithTotals =
          rows.map((row) => _buildAccountPair(row, queryWithSum)).toList();

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

  /// Watch a single account with its ID.
  Stream<AccountWithAmount?> watchAccountById(
    String id, {
    bool includeArchived = true,
    bool showGoals = false,
  }) {
    final queryWithSum = db._getCombinedQuery(
      accounts,
      includeArchived: includeArchived,
      showGoals: showGoals,
    );
    final filteredQuery = queryWithSum.query..where(accounts.id.equals(id));

    final mappedSelectable = filteredQuery.map(
      (row) => _buildAccountPair(row, queryWithSum),
    );

    return mappedSelectable.watchSingleOrNull();
  }

  /// Create an account using an [AccountsCompanion].
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

  /// Update an account using an [AccountsCompanion].
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

  /// Mark a list of accounts as deleted.
  Future<int> setAccountsDeleted(List<String> ids, bool status) =>
      (update(accounts)..where(
        (a) => a.id.isIn(ids),
      )).write(AccountsCompanion(isDeleted: Value(status)));

  /// Mark a list of accounts as archived.
  Future<int> setAccountsArchived(List<String> ids, bool status) =>
      (update(accounts)..where(
        (a) => a.id.isIn(ids),
      )).write(AccountsCompanion(isArchived: Value(status)));

  /// Permanently delete a list of accounts from the database.
  Future<int> permanentlyDeleteAccounts(List<String> ids) =>
      (delete(accounts)..where((a) => a.id.isIn(ids))).go();
}

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  /// Build a [GoalWithAmount] from a [TypedResult] that contains the goals
  /// table and the income and expenses queries from [query].
  GoalWithAmount _buildGoalPair(TypedResult row, QueryWithSums query) {
    final goal = row.readTable(goals);
    final expenses = row.read<double>(query.expenses);
    final income = row.read<double>(query.income);

    return GoalWithAmount(
      goal: goal,
      income: income ?? 0,
      expenses: expenses ?? 0,
    );
  }

  /// Watch a list of goals, filtered by the [filters].
  Stream<List<GoalWithAmount>> watchGoals({
    List<Filter>? filters,
    bool includeFinished = true,
    bool sortDescending = true,
  }) {
    final queryWithSum = db._getCombinedQuery(
      goals,
      includeArchived: includeFinished,
      showGoals: true,
    );

    if (filters != null) {
      queryWithSum.query.where(filters.buildWhereClause(db.transactions));
    }

    // View all of the goals in the database
    return queryWithSum.query.watch().map((rows) {
      final List<GoalWithAmount> goalsWithAmounts =
          rows.map((row) => _buildGoalPair(row, queryWithSum)).toList();

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

    // TODO: Maybe optimize with the only good use of getSignedTransactionsQuery
    final signedSumQueries = db._getTransactionSumQueries(showGoals: true);

    return query
        .addColumns([signedSumQueries.expenses, signedSumQueries.income])
        .map(
          (row) =>
              (row.read(signedSumQueries.expenses) ?? 0) -
              (row.read(signedSumQueries.income) ?? 0),
        )
        .watchSingle();
  }

  /// Mark a list of goals as deleted.
  Future<void> setGoalsDeleted(List<String> ids, bool status) => (update(goals)
    ..where(
      (g) => g.id.isIn(ids),
    )).write(GoalsCompanion(isDeleted: Value(status)));

  /// Mark a list of goals as finished, or archived.
  Future<void> setGoalsFinished(List<String> ids, bool status) => (update(goals)
    ..where(
      (g) => g.id.isIn(ids),
    )).write(GoalsCompanion(isArchived: Value(status)));

  /// Permanently delete a list of goals from the database.
  Future<int> permanentlyDeleteGoals(List<String> ids) =>
      (delete(goals)..where((g) => g.id.isIn(ids))).go();

  /// Create a goal using a [GoalsCompanion] object.
  Future<Goal> createGoal(GoalsCompanion entry) async {
    final id = entry.id.present ? entry.id.value : uuid.v4();
    final entryWithId = entry.copyWith(id: Value(id));

    final goal = into(goals).insertReturning(entryWithId);

    return goal;
  }

  /// Watch a goal by its ID.
  Stream<GoalWithAmount?> watchGoalById(
    String id, {
    bool includeFinished = true,
  }) {
    final queryWithSum = db._getCombinedQuery(
      goals,
      includeArchived: includeFinished,
      showGoals: true,
    );

    final filteredQuery = queryWithSum.query..where(goals.id.equals(id));

    final mappedSelectable = filteredQuery.map(
      (row) => _buildGoalPair(row, queryWithSum),
    );

    return mappedSelectable.watchSingleOrNull();
  }

  /// Update a goal using a [GoalsCompanion] object.
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

  /// Get a stream that watches a page of transaction objects, useful for
  /// paginated feeds.
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

  /// Get a stream that watches the total amount of money available in the
  /// database.
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

  /// Convert a [Transaction] object to a [HydratedTransaction], which includes
  /// amounted variants of its category, account, and goal.
  Future<HydratedTransaction> hydrateTransaction(
    Transaction transaction,
  ) async {
    // TODO: Optimize this
    GoalWithAmount? goal;
    CategoryWithAmount? category;
    AccountWithAmount? account;

    if (transaction.goalId != null) {
      goal = await db.goalDao.watchGoalById(transaction.goalId!).first;
    }

    if (transaction.category != null) {
      category =
          await db.categoryDao.watchCategoryById(transaction.category!).first;
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

  /// Get a [FinancialDataPoint] object using the income and expenses from a
  /// given date range.
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

  /// Retrieve a list of [FinancialDataPoint] objects based on a date range
  /// and how much they should be aggregated.
  ///
  /// [aggregationLevel] describes how much the data should be aggregated. For
  /// example, an [AggregationLevel.weekly] will convert a week's worth of
  /// transactions into one [FinancialDataPoint].
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

  /// Archive a list of transactions.
  Future<int> setTransactionsArchived(List<String> ids, bool status) =>
      (update(transactions)..where(
        (t) => t.id.isIn(ids),
      )).write(TransactionsCompanion(isArchived: Value(status)));

  /// Mark a list of transactions as deleted in the database.
  Future<int> setTransactionsDeleted(List<String> ids, bool status) =>
      (update(transactions)..where(
        (t) => t.id.isIn(ids),
      )).write(TransactionsCompanion(isDeleted: Value(status)));

  /// Permanently delete a list of transactions.
  Future<int> permanentlyDeleteTransactions(List<String> ids) =>
      (delete(transactions)..where((t) => t.id.isIn(ids))).go();

  /// Create a transaction from a [TransactionsCompanion] object.
  Future<Transaction> createTransaction(TransactionsCompanion entry) async {
    final id = entry.id.present ? entry.id.value : uuid.v4();
    final entryWithId = entry.copyWith(id: Value(id));

    final transaction = await into(transactions).insertReturning(entryWithId);

    return transaction;
  }

  /// Update a transaction using a [TransactionsCompanion] object.
  Future<Transaction> updateTransaction(TransactionsCompanion entry) async {
    final query = update(transactions)
      ..where((t) => t.id.equals(entry.id.value));

    return (await query.writeReturning(entry)).single;
  }

  /// Load a transaction from the database by its ID.
  Stream<Transaction?> watchTransactionById(String id) =>
      (select(transactions)
        ..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
}

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Get a [CategoryWithAmount] from a [TypedResult] that contains the
  /// categories table and the expenses and income from a [QueryWithSums].
  CategoryWithAmount _buildCategoryPair(TypedResult row, QueryWithSums query) =>
      CategoryWithAmount(
        category: row.readTable(categories),
        expenses: row.read<double>(query.expenses) ?? 0,
        income: row.read<double>(query.income) ?? 0,
      );

  /// Get a [CaseWhen] to use in a [CaseWhenExpression] for category dates.
  ///
  /// Used to get the resulting transaction amounts from the database based
  /// on a category's reset increment.
  CaseWhen<bool, String> _getCaseWhen(
    CategoryResetIncrement increment,
    bool isStart,
  ) {
    DateTimeRange timeRange =
        increment.relativeDateRange?.getRange() ??
        RelativeDateRange.today.getRange();

    // When the category's resetIncrement is equal to the increment,
    // then evaluate to the time range date.
    return CaseWhen(
      categories.resetIncrement.equalsValue(increment),
      then: Constant<String>(
        formatter.format(isStart ? timeRange.start : timeRange.end),
      ),
    );
  }

  /// Get the [QueryWithSums] that gets each category's expenses and income
  /// in relation to the category's [CategoryResetIncrement].
  QueryWithSums _getCategoriesWithAmountsQuery() {
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

    final sums = db._getTransactionSumQueries(
      additionalFilter: sumFilterCondition,
    );

    // Construct the actual expression to put in the query, used in case the
    // signed amount's sum returns null for some reason (which it never should)
    sums.expenses = coalesce([sums.expenses, const Constant(0.0)]);

    sums.income = coalesce([sums.income, const Constant(0.0)]);

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
          ..addColumns([sums.expenses, sums.income])
          ..groupBy([categories.id]);

    return QueryWithSums(
      queryWithSum,
      income: sums.income,
      expenses: sums.expenses,
    );
  }

  /// Get a [QueryWithSums] that includes categories and their respective
  /// expenses and income amounts.
  QueryWithSums _getQueryWithSum({
    bool includeArchived = false,
    bool sumByResetIncrement = true,
  }) {
    QueryWithSums queryWithSum;

    if (sumByResetIncrement) {
      queryWithSum = _getCategoriesWithAmountsQuery();
    } else {
      queryWithSum = db._getCombinedQuery(
        categories,
        includeArchived: includeArchived,
        showGoals: true,
      );
    }

    return queryWithSum;
  }

  /// Watch a list of categories, filtered by the [filters].
  Stream<List<CategoryWithAmount>> watchCategories({
    List<Filter>? filters,
    bool includeArchived = false,
    bool sumByResetIncrement = true,
  }) {
    final queryWithSum = _getQueryWithSum(
      includeArchived: includeArchived,
      sumByResetIncrement: sumByResetIncrement,
    );

    if (filters != null) {
      queryWithSum.query.where(filters.buildWhereClause(db.transactions));
    }

    return queryWithSum.query.watch().map(
      (rows) =>
          rows.map((row) => _buildCategoryPair(row, queryWithSum)).toList(),
    );
  }

  /// Watch a category by its ID.
  Stream<CategoryWithAmount?> watchCategoryById(
    String id, {
    bool includeArchived = false,
    bool sumByResetIncrement = true,
  }) {
    final queryWithSum = _getQueryWithSum(
      includeArchived: includeArchived,
      sumByResetIncrement: sumByResetIncrement,
    );

    final singleCategoryQuery =
        queryWithSum.query..where(categories.id.equals(id));

    return singleCategoryQuery.watchSingleOrNull().map(
      (row) => row == null ? null : _buildCategoryPair(row, queryWithSum),
    );
  }

  /// Create a category using a [CategoriesCompanion] object.
  Future<Category> createCategory(CategoriesCompanion entry) async {
    final id = entry.id.present ? entry.id.value : uuid.v4();
    // 2. Create a companion that definitely includes the ID
    final entryWithId = entry.copyWith(id: Value(id));

    final category = await into(categories).insertReturning(entryWithId);

    return category;
  }

  /// Update a category using a [CategoriesCompanion] object.
  ///
  /// The companion must have the ID of the object it wishes to update. This
  /// method will not automatically create a new category.
  Future<Category> updateCategory(CategoriesCompanion entry) async {
    final query = update(categories)..where((t) => t.id.equals(entry.id.value));

    return (await query.writeReturning(entry)).single;
  }

  /// Mark a list of categories as archived.
  Future<int> setCategoriesArchived(List<String> ids, bool status) =>
      (update(categories)..where(
        (t) => t.id.isIn(ids),
      )).write(CategoriesCompanion(isArchived: Value(status)));

  /// Mark a list of categories as deleted.
  Future<int> setCategoriesDeleted(List<String> ids, bool status) =>
      (update(categories)..where(
        (c) => c.id.isIn(ids),
      )).write(CategoriesCompanion(isDeleted: Value(status)));

  /// Permanently delete a list of categories from the database.
  Future<int> permanentlyDeleteCategories(List<String> ids) =>
      (delete(categories)..where((c) => c.id.isIn(ids))).go();

  /// Watch the total amount of categories owned by the user.
  Stream<int> watchCategoryCount() {
    return categories.count().watchSingle();
  }
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

  /// Generates a [QueryWithSums] object that will include a select query on the
  /// [relatedTable] that will not include deleted results, and two [Expression]
  /// objects to represent expenses and income on [relatedTable]'s results.
  ///
  /// Will not show archived results or results associated with a goal, unless
  /// [includeArchived] and [showGoals] are set to true, respectively.
  QueryWithSums _getCombinedQuery<T extends SoftDeletableTable>(
    TableInfo<T, dynamic> relatedTable, {
    bool includeArchived = false,
    bool showGoals = false,
  }) {
    var query = select(
      relatedTable,
    ).join([leftOuterJoin(transactions, _getJoinCondition(relatedTable))]);

    query.where(relatedTable.asDslTable.isDeleted.not());

    if (!includeArchived) {
      query.where(relatedTable.asDslTable.isArchived.not());
    }

    TransactionSumPair sums = _getTransactionSumQueries(
      includeArchived: includeArchived,
      showGoals: showGoals,
    );

    query.addColumns([sums.expenses, sums.income]);
    query.groupBy([relatedTable.asDslTable.id]);

    return QueryWithSums(query, income: sums.income, expenses: sums.expenses);
  }

  /// Get a condition used for table joins depending on which table is being
  /// used.
  ///
  /// Useful to keep code dry.
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

  /// Get an [Expression] that matches the transactions of type [type].
  ///
  /// Used to ensure all reads of transactions don't include archived or
  /// deleted records. Can also be filtered by an [additionalFilter].
  Expression<double> _getTypeExpr({
    required TransactionType type,
    bool includeArchived = false,
    bool showGoals = false,
    Expression<bool>? additionalFilter,
  }) {
    Expression<bool> sumCondition =
        transactions.type.equalsValue(type) &
        transactions.isDeleted.not() &
        transactions.date.isSmallerOrEqualValue(
          formatter.format(DateTime.now()),
        );

    if (!includeArchived) {
      sumCondition = sumCondition & transactions.isArchived.not();
    }

    if (!showGoals) {
      sumCondition = sumCondition & transactions.goalId.isNull();
    }

    if (additionalFilter != null) {
      sumCondition = sumCondition & additionalFilter;
    }

    return transactions.amount.sum(filter: sumCondition);
  }

  /// Get a [TransactionSumPair] to represent expenses and income from the
  /// database.
  TransactionSumPair _getTransactionSumQueries({
    bool includeArchived = false,
    bool showGoals = false,
    Expression<bool>? additionalFilter,
  }) {
    return TransactionSumPair(
      expenses: _getTypeExpr(
        type: TransactionType.expense,
        includeArchived: includeArchived,
        showGoals: showGoals,
        additionalFilter: additionalFilter,
      ),
      income: _getTypeExpr(
        type: TransactionType.income,
        includeArchived: includeArchived,
        showGoals: showGoals,
        additionalFilter: additionalFilter,
      ),
    );
  }

  /// Get the sum of all of the transactions' income minus its expenses
  Expression<double> getSignedTransactionSumQuery({
    bool includeArchived = false,
    bool summed = true,
    bool showGoals = false,
  }) {
    // Mainly uses "summed" for backwards compatibility with code I wrote less
    // than an hour ago

    // Don't show transactions with goals in totals, since the money should be
    // 'put away' into a goal.
    List<CaseWhen<bool, double>> cases;
    final dateExpr = transactions.date.isSmallerOrEqualValue(
      formatter.format(DateTime.now()),
    );

    if (includeArchived) {
      cases = [
        CaseWhen(
          transactions.type.equalsValue(TransactionType.income) &
              transactions.isDeleted.not() &
              dateExpr,
          then: transactions.amount,
        ),
        CaseWhen(
          transactions.type.equalsValue(TransactionType.expense) &
              transactions.isDeleted.not() &
              dateExpr,
          then: -transactions.amount,
        ),
      ];
    } else {
      cases = [
        CaseWhen(
          transactions.type.equalsValue(TransactionType.income) &
              transactions.isDeleted.not() &
              transactions.isArchived.not() &
              dateExpr,
          then: transactions.amount,
        ),
        CaseWhen(
          transactions.type.equalsValue(TransactionType.expense) &
              transactions.isDeleted.not() &
              transactions.isArchived.not() &
              dateExpr,
          then: -transactions.amount,
        ),
      ];
    }

    // Make sure this case takes priority
    if (!showGoals) {
      cases.insert(
        0,
        CaseWhen(transactions.goalId.isNotNull(), then: const Constant(0)),
      );
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
