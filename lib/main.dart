import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/views/components/nav_manager.dart';
import 'package:budget/services/powersync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/settings.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

ThemeMode? theme;

Future<void> setup() async {
  final logger = AppLogger().logger;

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  var settings = await loadSettings();

  logger.i('Loaded settings');
  logger.d(
    'Settings: ${settings.map((e) => "${e.type.name} ${e.name}: ${e.value}")}',
  );

  switch (settings.where((element) => element.name == 'Theme').first.value) {
    case 'System':
      theme = ThemeMode.system;
    case 'Dark':
      theme = ThemeMode.dark;
    case 'Light':
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
  // I have a lot of providers
  final dbProvider = Provider<AppDatabase>(
    create: (_) => appDb,
    dispose: (_, db) => db.close(),
  );

  final transactionProvider = ChangeNotifierProvider<TransactionProvider>(
    create: (context) => TransactionProvider(),
  );

  final snackBarProvider = ChangeNotifierProvider<SnackbarProvider>(
    create: (_) => SnackbarProvider(),
  );

  await setup();

  runApp(
    MultiProvider(
      providers: [dbProvider, transactionProvider, snackBarProvider],
      child: const BudgetApp(),
    ),
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
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
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
          themeMode: theme,
        );
      },
    );
  }
}
