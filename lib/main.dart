import 'package:budget/services/providers/auth_provider.dart';
import 'package:budget/services/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/appui/components/nav_manager.dart';
import 'package:budget/services/powersync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:provider/provider.dart';
import 'package:budget/services/providers/settings.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await dotenv.load();
  await openDatabase();

  final settingsService = SettingsService();
  await settingsService.loadSettings();

  PlatformDispatcher.instance.onError = (error, stack) {
    // If the user is offline, Supabase will try to raise an AuthError because
    // the remote can't be reached.
    if (error is AuthException &&
        error.message.contains('Failed host lookup')) {
      AppLogger().logger.i(
        'Caught expected offline authentication error: ${error.message}',
      );
      return true;
    } else {
      return false;
    }
  };

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

  final authProvider = ChangeNotifierProvider.value(value: AuthProvider());

  runApp(
    MultiProvider(
      providers: [dbProvider, snackBarProvider, settingsProvider, authProvider],
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
