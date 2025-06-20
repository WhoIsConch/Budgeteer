import 'package:budget/services/app_database.dart';
import 'package:budget/services/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:budget/services/powersync_schema.dart';

// Contents of this powersync.dart file are largely borrowed from Powersync's
// supabase-todolist-drift example project found here:
// https://github.com/powersync-ja/powersync.dart/blob/main/demos/supabase-todolist-drift/

/// Postgres Response codes that we cannot recover from by retrying.
final List<RegExp> fatalResponseCodes = [
  // Class 22 — Data Exception
  // Examples include data type mismatch.
  RegExp(r'^22...$'),
  // Class 23 — Integrity Constraint Violation.
  // Examples include NOT NULL, FOREIGN KEY and UNIQUE violations.
  RegExp(r'^23...$'),
  // INSUFFICIENT PRIVILEGE - typically a row-level security violation
  RegExp(r'^42501$'),
];

class SupabaseConnector extends PowerSyncBackendConnector {
  Future<void>? _refreshFuture;

  SupabaseConnector();

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Wait for pending session refresh
    await _refreshFuture;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) return null;

    // Token is used to authenticate against PowerSync
    final token = session.accessToken;

    // These are for debugging purposes
    final userId = session.user.id;
    final expiresAt =
        session.expiresAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);

    return PowerSyncCredentials(
      endpoint: dotenv.env['POWERSYNC_URL']!,
      token: token,
      userId: userId,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    // When there is data to upload, this method is called. If it errors, the
    // method is retried periodically.
    final transaction = await database.getNextCrudTransaction();

    if (transaction == null) return;

    final rest = Supabase.instance.client.rest;
    // CrudEntry? lastOp;

    try {
      for (var op in transaction.crud) {
        // lastOp = op;

        final table = rest.from(op.table);

        if (op.op == UpdateType.put) {
          var data = Map<String, dynamic>.of(op.opData!);
          data['id'] = op.id;
          await table.upsert(data);
        } else if (op.op == UpdateType.patch) {
          await table.update(op.opData!).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete().eq('id', op.id);
        }
      }

      await transaction.complete();
    } on PostgrestException catch (e) {
      if (e.code != null &&
          fatalResponseCodes.any((re) => re.hasMatch(e.code!))) {
        // TODO: Logging to ensure the bug is logged.
        // Usually this is a bug in the application

        print('ERR IN UPLOADDATA: $e');

        await transaction.complete();
      } else {
        rethrow;
      }
    }
    print('ANOTHER WIN FOR THE OGS');
  }
}

// Global reference to the databases
late final PowerSyncDatabase db;
late final AppDatabase appDb;

bool isLoggedIn() =>
    Supabase.instance.client.auth.currentSession?.accessToken != null;

String? getUserId() => Supabase.instance.client.auth.currentSession?.user.id;

Future<String> getDatabasePath() async {
  const dbFilename = 'budgeteer.db';

  if (kIsWeb) {
    return dbFilename;
  }

  final dir = await getApplicationSupportDirectory();
  return join(dir.path, dbFilename);
}

Future<void> openDatabase() async {
  db = PowerSyncDatabase(
    schema: powersyncAppSchema,
    path: await getDatabasePath(),
  );

  await db.initialize();

  appDb = AppDatabase(db);

  await loadSupabase();

  SupabaseConnector? currentConnector;

  if (isLoggedIn()) {
    currentConnector = SupabaseConnector();
    db.connect(
      connector: currentConnector,
      options: const SyncOptions(
        syncImplementation: SyncClientImplementation.rust,
      ),
    );
  }

  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final AuthChangeEvent event = data.event;

    if (event == AuthChangeEvent.signedIn) {
      currentConnector = SupabaseConnector();

      db.connect(connector: currentConnector!);
    } else if (event == AuthChangeEvent.signedOut) {
      currentConnector = null;
      await db.disconnect();
    } else if (event == AuthChangeEvent.tokenRefreshed) {
      currentConnector?.prefetchCredentials();
    }
  });

  // await configureFts(db);
}

Future<void> logout() async {
  await Supabase.instance.client.auth.signOut();
  await db.disconnectAndClear();
}
