import 'package:budget/panels/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/settings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final provider = TransactionProvider();
  provider.loadTransactions();
  provider.loadCategories();

  setup().then(((value) {
    runApp(ChangeNotifierProvider(
        create: (context) => provider, child: const BudgetApp()));
  }));
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

    DatabaseHelper().close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      DatabaseHelper().close();
    }
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
