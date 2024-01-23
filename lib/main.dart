import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'home_card.dart';
import 'transactions.dart';

void main() {
  runApp(const MyApp());
}

enum Page {
  home(0),
  transactions(1);

  const Page(this.value);
  final int value;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      return MaterialApp(
          title: 'Flutter Demo',
          home: const HomePage(),
          theme: ThemeData(
            colorScheme: lightDynamic ?? ThemeData.light().colorScheme,
          ),
          darkTheme: ThemeData(
            colorScheme: darkDynamic ?? ThemeData.dark().colorScheme,
          ),
          themeMode: ThemeMode.system);
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

  void indexCallback(Page page) {
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
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person),
              label: "Account",
            )
          ],
        ),
        body: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: HomeSpread(swapCallback: indexCallback),
            ),
          ),
          const SafeArea(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: TransactionsPage(),
          )),
          const SafeArea(
              child: Padding(
            padding: EdgeInsets.all(16),
            child: Text("Account"),
          ))
        ][selectedIndex]);
  }
}

class HomeSpread extends StatelessWidget {
  const HomeSpread({super.key, required this.swapCallback});

  final Function swapCallback;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(
            height: 200,
            child: HomeCard(title: "Total Balance", content: "\$1,000")),
        const SizedBox(height: 16),
        const SizedBox(
          height: 160,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  flex: 16,
                  child: HomeCard(title: "Net Gain Today", content: "\$1,000")),
              Spacer(),
              Expanded(
                  flex: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          flex: 8,
                          child: CardButton(content: "Add an\nexpense")),
                      Spacer(),
                      Expanded(
                          flex: 8, child: CardButton(content: "Add income")),
                    ],
                  ))
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
            height: 70,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 10,
                    child: CardButton(
                        content: "Go to Totals\nOverview",
                        callback: () => swapCallback(Page.transactions)),
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 10,
                    child: CardButton(
                        content: "Go to Budget\nOverview",
                        callback: () => swapCallback(Page.transactions)),
                  )
                ]))
      ],
    );
  }
}
