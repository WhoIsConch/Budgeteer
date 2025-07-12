import 'dart:io';

import 'package:budget/services/app_database.dart';
import 'package:budget/services/powersync_schema.dart';
import 'package:path/path.dart';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';

Directory getTempDir() =>
    Directory(join(Directory.systemTemp.path, 'budgeteer_tests'));

String getTestDatabasePath() {
  final uuid = Uuid();
  final tempDir = getTempDir();

  return join(tempDir.path, 'powersync-test-${uuid.v4()}.db');
}

Future<AppDatabase> getTestDatabase(String path) async {
  final powerSync = PowerSyncDatabase(schema: powersyncAppSchema, path: path);

  await powerSync.initialize();

  return AppDatabase(powerSync);
}
