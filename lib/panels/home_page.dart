import 'package:budget/panels/login.dart';
import 'package:budget/tools/enums.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:budget/panels/home.dart';
import 'package:budget/panels/spending.dart';
import 'package:budget/panels/account.dart';
import 'package:budget/panels/statistics.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  void indexCallback(PageType page) {
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData) {
            return const HomePage();
          }

          return const LoginPage();
        });
  }
}
