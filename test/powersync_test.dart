import 'dart:io';

import 'package:budget/models/enums.dart';
import 'package:async/async.dart';
import 'package:budget/services/powersync_schema.dart';
import 'package:drift/drift.dart' hide isNull;
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
  });
}
