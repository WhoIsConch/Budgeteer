import 'dart:io';

import 'package:budget/models/enums.dart';
import 'package:async/async.dart';
import 'package:budget/models/filters.dart';
import 'package:budget/services/powersync_schema.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:powersync/powersync.dart';
import 'package:test/test.dart';
import 'package:budget/services/app_database.dart';
import 'package:uuid/uuid.dart';

String getTestDatabasePath() {
  const dbFilename = 'powersync-test.db';
  final dir = Directory.current.absolute.path;

  return join(dir, dbFilename);
}

Directory getTempDir() =>
    Directory(join(Directory.systemTemp.path, 'budgeteer_tests'));

TransactionsCompanion getExampleCompanion() => TransactionsCompanion(
  title: Value('Test Transaction'),
  amount: Value(50),
  type: Value(TransactionType.expense),
  date: Value(DateTime.now()),
);

void main() {
  late AppDatabase database;
  late PowerSyncDatabase powerSync;
  final List<String> pathsToDelete = [];

  setUp(() async {
    final uuid = Uuid();
    final tempDir = getTempDir();
    final testDbPath = join(tempDir.path, 'powersync-test-${uuid.v4()}.db');

    // Create the temporary test directory
    await tempDir.create();

    powerSync = PowerSyncDatabase(schema: powersyncAppSchema, path: testDbPath);

    await powerSync.initialize();

    database = AppDatabase(powerSync);

    pathsToDelete.add(testDbPath);
  });

  tearDown(() async {
    await database.close();
    await powerSync.close();
  });

  tearDownAll(() async {
    final tempDir = getTempDir();

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('transactions', () {
    late TransactionDao dao;

    setUp(() {
      dao = database.transactionDao;
    });

    group('basic transaction database operations', () {
      test('transactions can be created', () async {
        // Create a new transaction
        final transaction = await dao.createTransaction(getExampleCompanion());
        final laterTransaction =
            await dao.watchTransactionById(transaction.id).first;

        expect(transaction.id, laterTransaction!.id);
        expect(transaction.title, laterTransaction.title);
      });

      test('transactions can be deleted', () async {
        final transaction = await dao.createTransaction(getExampleCompanion());

        await dao.permanentlyDeleteTransactions([transaction.id]);

        final after = await dao.watchTransactionById(transaction.id).first;

        expect(after, null);
      });

      test('transactions can be edited', () async {
        final transaction = await dao.createTransaction(getExampleCompanion());

        await dao.updateTransaction(
          TransactionsCompanion(
            id: Value(transaction.id),
            title: Value('Updated title'),
          ),
        );

        final after = await dao.watchTransactionById(transaction.id).first;

        expect(after?.title, 'Updated title');
      });

      test('transaction edits push to its stream', () async {
        final transaction = await dao.createTransaction(getExampleCompanion());

        final expectation = expectLater(
          dao.watchTransactionById(transaction.id).map((t) => t?.title),
          emitsInOrder(['Test Transaction', 'Updated title']),
        );

        await dao.updateTransaction(
          TransactionsCompanion(
            id: Value(transaction.id),
            title: Value('Updated title'),
          ),
        );
        await expectation;
      });

      test('transaction deletions push to its stream', () async {
        final transaction = await dao.createTransaction(getExampleCompanion());

        final expectation = expectLater(
          dao.watchTransactionById(transaction.id).map((t) => t?.title),
          emitsInOrder(['Test Transaction', null]),
        );

        await dao.permanentlyDeleteTransactions([transaction.id]);

        await expectation;
      });
    });

    group('transactions and totals', () {
      test('transactions count towards totals', () async {
        // Use multiple expectLater to ensure the stream updates properly
        // after each write
        final stream = StreamQueue(dao.watchTotalAmount());

        await expectLater(stream, emits(isNull));

        // Create the first transaction of +50
        await dao.createTransaction(
          TransactionsCompanion.insert(
            title: 't1',
            amount: 50,
            date: DateTime.now(),
            type: TransactionType.income,
          ),
        );

        await expectLater(stream, emits(50));

        // Create a second transaction of -30
        await dao.createTransaction(
          TransactionsCompanion.insert(
            title: 't2',
            amount: 30,
            date: DateTime.now(),
            type: TransactionType.expense,
          ),
        );

        await expectLater(stream, emits(20));
      });

      test('archived transactions don\'t count towards totals', () async {
        final expectedTotals = expectLater(
          dao.watchTotalAmount(),
          emitsInOrder([isNull, -50, isNull]),
        );

        final transaction = await dao.createTransaction(getExampleCompanion());

        await Future.delayed(Duration(milliseconds: 100));

        await dao.setTransactionsArchived([transaction.id], true);

        await expectedTotals;
      });

      test('deleted transactions don\'t count towards totals', () async {
        final expectedTotals = expectLater(
          dao.watchTotalAmount(),
          emitsInOrder([isNull, -50, isNull]),
        );

        final transaction = await dao.createTransaction(getExampleCompanion());

        await Future.delayed(Duration(milliseconds: 100));

        await dao.setTransactionsDeleted([transaction.id], true);

        await expectedTotals;
      });
    });

    group('transaction filtering and sorting', () {
      setUp(() async {
        // Create a group of transactions to be filtered and sorted
        final companions = [
          TransactionsCompanion.insert(
            title: 'A tran',
            amount: 50,
            type: TransactionType.income,
            date: DateTime.now().subtract(Duration(days: 7)),
            notes: Value('Note'),
          ),
          TransactionsCompanion.insert(
            title: 'B tran',
            amount: 20,
            type: TransactionType.expense,
            date: DateTime.now().subtract(Duration(days: 2)),
          ),
          TransactionsCompanion.insert(
            title: 'C tran',
            amount: 10,
            type: TransactionType.expense,
            date: DateTime.now().subtract(Duration(days: 4)),
          ),
        ];

        for (var companion in companions) {
          await dao.createTransaction(companion);
        }
      });

      group('transaction sorting', () {
        test('transactions are sorted by date descending by default', () async {
          final transactions = await dao.watchTransactionsPage().first;
          final List<Transaction> sorted = List.from(transactions);

          // Create a new list that is re-sorted to expected values
          // comparing b with a ensures a descending sort
          sorted.sort((a, b) => b.date.compareTo(a.date));

          expect(transactions, sorted);
        });

        test(
          'transactions can be sorted by title in descending order',
          () async {
            final transactions =
                await dao
                    .watchTransactionsPage(
                      sort: Sort(SortType.title, SortOrder.descending),
                    )
                    .first;
            final List<Transaction> sorted = List.from(transactions);

            sorted.sort((a, b) => b.title.compareTo(a.title));

            expect(transactions, sorted);
          },
        );

        test(
          'transactions can be sorted by title in ascending order',
          () async {
            final transactions =
                await dao
                    .watchTransactionsPage(
                      sort: Sort(SortType.title, SortOrder.ascending),
                    )
                    .first;
            final List<Transaction> sorted = List.from(transactions);

            sorted.sort((a, b) => a.title.compareTo(b.title));

            expect(transactions, sorted);
          },
        );

        test(
          'transactions can be sorted by date in descending order',
          () async {
            final transactions =
                await dao
                    .watchTransactionsPage(
                      sort: Sort(SortType.date, SortOrder.descending),
                    )
                    .first;
            final List<Transaction> sorted = List.from(transactions);

            sorted.sort((a, b) => b.date.compareTo(a.date));

            expect(transactions, sorted);
          },
        );

        test('transactions can be sorted by date in ascending order', () async {
          final transactions =
              await dao
                  .watchTransactionsPage(
                    sort: Sort(SortType.date, SortOrder.ascending),
                  )
                  .first;
          final List<Transaction> sorted = List.from(transactions);

          sorted.sort((a, b) => a.date.compareTo(b.date));

          expect(transactions, sorted);
        });

        test(
          'transactions can be sorted by amount in descending order',
          () async {
            final transactions =
                await dao
                    .watchTransactionsPage(
                      sort: Sort(SortType.amount, SortOrder.descending),
                    )
                    .first;
            final List<Transaction> sorted = List.from(transactions);

            sorted.sort((a, b) => b.amount.compareTo(a.amount));

            expect(transactions, sorted);
          },
        );

        test(
          'transactions can be sorted by amount in ascending order',
          () async {
            final transactions =
                await dao
                    .watchTransactionsPage(
                      sort: Sort(SortType.amount, SortOrder.ascending),
                    )
                    .first;
            final List<Transaction> sorted = List.from(transactions);

            sorted.sort((a, b) => a.amount.compareTo(b.amount));

            expect(transactions, sorted);
          },
        );
      });

      group('transaction filtering', () {
        test('transactions can be searched by title text', () async {
          // TODO: Make text search non-exact
          final transactions =
              await dao
                  .watchTransactionsPage(filters: [TextFilter('A tran')])
                  .first;

          expect(transactions.length, 1);
          expect(transactions.first.title, 'A tran');
        });

        test('transactions can be searched by note text', () async {
          final transactions =
              await dao
                  .watchTransactionsPage(filters: [TextFilter('Note')])
                  .first;

          expect(transactions.length, 1);
          expect(transactions.first.title, 'A tran');
        });

        test('transactions can be searched by date range', () async {
          final transactions =
              await dao
                  .watchTransactionsPage(
                    filters: [
                      DateRangeFilter(
                        DateTimeRange(
                          start: DateTime.now().subtract(Duration(days: 4)),
                          end: DateTime.now(),
                        ),
                      ),
                    ],
                  )
                  .first;

          expect(transactions.length, 2);
        });

        test('transactions can be searched by exact amount', () async {
          final transactions =
              await dao
                  .watchTransactionsPage(
                    filters: [AmountFilter(AmountFilterType.exactly, 50)],
                  )
                  .first;

          expect(transactions.length, 1);
        });

        test('transactions can be searched by less than amount', () async {
          final transactions =
              await dao
                  .watchTransactionsPage(
                    filters: [AmountFilter(AmountFilterType.lessThan, 50)],
                  )
                  .first;

          expect(transactions.length, 2);
        });

        test('transactions can be searched by greater than amount', () async {
          final transactions =
              await dao
                  .watchTransactionsPage(
                    filters: [AmountFilter(AmountFilterType.greaterThan, 3)],
                  )
                  .first;

          expect(transactions.length, 1);
        });
      });
    });
  });
}
