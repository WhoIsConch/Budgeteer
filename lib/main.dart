import 'package:budget/services/app_database.dart';
import 'package:budget/views/components/nav_manager.dart';
import 'package:budget/services/powersync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/settings.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

ThemeMode? theme;

Future<void> setup() async {
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  var settings = await loadSettings();

  switch (settings.where((element) => element.name == "Theme").first.value) {
    case "System":
      theme = ThemeMode.system;
    case "Dark":
      theme = ThemeMode.dark;
    case "Light":
      theme = ThemeMode.light;
    default:
      theme = ThemeMode.system;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  await openDatabase();

  // Define the providers
  final dbProvider = Provider<AppDatabase>(
    create: (_) => appDb,
    dispose: (_, db) => db.close(),
  );

  final deletionManagerProvider = Provider<DeletionManager>(
    create: (context) => DeletionManager(context.read<TransactionDao>()),
    dispose: (_, value) => value.dispose(),
  );

  final daoProvider = ProxyProvider<AppDatabase, TransactionDao>(
    update: (_, db, __) => TransactionDao(db),
  );

  final transactionProvider = ChangeNotifierProvider<TransactionProvider>(
      create: (context) => TransactionProvider());

  await setup();

  runApp(
    MultiProvider(providers: [
      dbProvider,
      daoProvider,
      deletionManagerProvider,
      transactionProvider,
    ], child: const BudgetApp()),
  );
}

class BudgetApp extends StatefulWidget {
  const BudgetApp({super.key});

  @override
  State<BudgetApp> createState() => _BudgetAppState();
}

class _BudgetAppState extends State<BudgetApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      return MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          title: 'Budgeteer',
          home: const AuthWrapper(),
          theme: ThemeData(
            colorScheme:
                lightDynamic?.harmonized() ?? ThemeData.light().colorScheme,
          ),
          darkTheme: ThemeData(
            colorScheme:
                darkDynamic?.harmonized() ?? ThemeData.dark().colorScheme,
          ),
          themeMode: theme);
    });
  }
}
