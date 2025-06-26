import 'package:budget/services/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/appui/components/nav_manager.dart';
import 'package:budget/services/powersync.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:provider/provider.dart';
import 'package:budget/services/providers/settings.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await dotenv.load();
  await openDatabase();

  final settingsService = SettingsService();
  await settingsService.loadSettings();

  // Define the providers
  // I have a lot of providers
  final dbProvider = Provider<AppDatabase>(
    create: (_) => appDb,
    dispose: (_, db) => db.close(),
  );

  final snackBarProvider = ChangeNotifierProvider<SnackbarProvider>(
    create: (_) => SnackbarProvider(),
  );

  final settingsProvider = ChangeNotifierProvider.value(value: settingsService);

  runApp(
    MultiProvider(
      providers: [dbProvider, snackBarProvider, settingsProvider],
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
            useMaterial3: true,
            colorScheme:
                darkDynamic?.harmonized() ?? ThemeData.dark().colorScheme,
          ),
        );
      },
    );
  }
}
