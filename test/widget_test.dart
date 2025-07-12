// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:budget/appui/components/objects_list.dart';
import 'package:budget/appui/components/status.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/services/providers/snackbar_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget/main.dart';
import 'package:provider/provider.dart';

import 'db.dart';

void main() {
  late AppDatabase database;
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BudgetApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  setUp(() async {
    await getTempDir().create();

    database = await getTestDatabase(getTestDatabasePath());
  });

  testWidgets('transactions list shows transactions', (
    WidgetTester tester,
  ) async {
    final snackBarProvider = ChangeNotifierProvider.value(
      value: SnackbarProvider(),
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider.value(value: database), snackBarProvider],
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ObjectsList<TransactionTileableAdapter>(),
          ),
        ),
      );

      await tester.idle();
      // await tester.pump(Duration.zero);
    });

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
