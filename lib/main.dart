import 'package:budget/panels/statistics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:budget/panels/home.dart';
import 'package:budget/panels/spending.dart';
import 'package:budget/panels/account.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/enums.dart' as tools;
import 'package:budget/tools/api.dart';
import 'package:budget/tools/settings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          scaffoldMessengerKey: tools.scaffoldMessengerKey,
          title: 'Budgeteer',
          home: const HomePage(),
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  void indexCallback(tools.PageType page) {
    setState(() {
      selectedIndex = page.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Scaffold(
        bottomNavigationBar: NavigationBar(
          backgroundColor: theme.appBarTheme.backgroundColor,
          selectedIndex: selectedIndex,
          onDestinationSelected: (value) {
            setState(() {
              selectedIndex = value;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: "Home",
              selectedIcon: Icon(Icons.home),
            ),
            NavigationDestination(
              icon: Icon(Icons.paid_outlined),
              selectedIcon: Icon(Icons.paid),
              label: "Spending",
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: "Budget",
            ),
            NavigationDestination(
              icon: Icon(Icons.code),
              selectedIcon: Icon(Icons.code),
              label: "Debug",
            ),
          ],
        ),
        body: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Overview(swapCallback: indexCallback),
            ),
          ),
          const SafeArea(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: SpendingOverview(),
          )),
          const SafeArea(
              child: Padding(padding: EdgeInsets.all(16), child: BudgetPage())),
          const SafeArea(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: Account(),
          )),
        ][selectedIndex]);
  }
}
