import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/views/history.dart';
import 'package:budget/views/login.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/views/panels/manage_category.dart';
import 'package:budget/views/panels/manage_transaction.dart';

import 'package:flutter/material.dart';
import 'package:budget/views/home.dart';
import 'package:budget/views/account.dart';
import 'package:budget/views/statistics.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NavManager extends StatefulWidget {
  const NavManager({super.key});

  @override
  State<NavManager> createState() => _NavManagerState();
}

class _NavManagerState extends State<NavManager>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  bool _isMenuOpen = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  final LayerLink _appBarLink = LayerLink();

  void _toggleFabMenu() => setState(() {
        _isMenuOpen = !_isMenuOpen;
        if (_isMenuOpen) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });

  List<ExpandedButtonData> get _expandedButtonsData => [
        ExpandedButtonData(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            text: "Category",
            onPressed: () {
              Navigator.of(context).push(DialogRoute(
                  context: context,
                  builder: (_) => const ManageCategoryDialog()));
              _toggleFabMenu();
            }),
        ExpandedButtonData(
            text: "Account", icon: const Icon(Icons.wallet), onPressed: () {}),
        ExpandedButtonData(
            text: "Goal", icon: const Icon(Icons.flag), onPressed: () {}),
        ExpandedButtonData(
            text: "Transaction",
            icon: const Icon(Icons.attach_money),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ManageTransactionPage()));
              _toggleFabMenu();
            })
      ];

  List<Widget> _buildActionButtons() => List.generate(
      _expandedButtonsData.length,
      (index) => ScaleTransition(
          alignment: Alignment.centerRight,
          scale: _scaleAnimation,
          child: SpeedDialExpandedButton(data: _expandedButtonsData[index])));

  @override
  void dispose() {
    _animationController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _scaleAnimation = CurvedAnimation(
        parent: _animationController, curve: Curves.easeOutBack);
  }

  void indexCallback(PageType page) {
    setState(() {
      selectedIndex = page.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    bool snackbarPresent = context.watch<SnackbarProvider>().isSnackBarVisible;

    return Stack(
      children: [
        Scaffold(
            bottomNavigationBar: CompositedTransformTarget(
              link: _appBarLink,
              child: NavigationBar(
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
                    icon: Icon(Icons.history_outlined),
                    selectedIcon: Icon(Icons.history),
                    label: "Activity",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: "Stats",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.code),
                    selectedIcon: Icon(Icons.code),
                    label: "Debug",
                  ),
                ],
              ),
            ),
            body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 100),
                child: [
                  const SafeArea(
                    key: ValueKey('overview'),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: HomePage(),
                    ),
                  ),
                  const SafeArea(
                      key: ValueKey('history'),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: History(),
                      )),
                  const SafeArea(
                      key: ValueKey('budget'),
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: StatisticsPage())),
                  const SafeArea(
                      key: ValueKey('account'),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Account(),
                      )),
                ][selectedIndex])),
        if (_isMenuOpen)
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: _toggleFabMenu,
                child: Container(
                    // Fill the screen with darkness when the FAB is pressed
                    color: Colors.black.withAlpha(200)),
              ),
            ),
          ),
        CompositedTransformFollower(
            link: _appBarLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topRight,
            followerAnchor: Alignment.bottomRight,
            offset: Offset(-16.0, snackbarPresent ? -64.0 : -16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_animationController.isDismissed)
                    ..._buildActionButtons(),
                  const SizedBox(height: 4),
                  FloatingActionButton(
                      backgroundColor:
                          Theme.of(context).colorScheme.tertiaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onTertiaryContainer,
                      heroTag: 'home_fab',
                      onPressed: _toggleFabMenu,
                      child: RotationTransition(
                        turns: _rotateAnimation,
                        child: const Icon(size: 28, Icons.add),
                      ))
                ]))
      ],
    );
  }
}

class ExpandedButtonData {
  final Icon icon;
  final String text;
  final void Function() onPressed;

  const ExpandedButtonData(
      {required this.icon, required this.text, required this.onPressed});
}

class SpeedDialExpandedButton extends StatelessWidget {
  final ExpandedButtonData data;

  const SpeedDialExpandedButton({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child:
                Text(data.text, style: Theme.of(context).textTheme.titleMedium),
          ),
          FloatingActionButton.small(
              heroTag: "${data.text.toLowerCase()}_fab",
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onTertiaryContainer,
              onPressed: data.onPressed,
              child: data.icon)
        ],
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          Widget body;

          if (snapshot.connectionState == ConnectionState.waiting) {
            body = const Scaffold(
                key: ValueKey('loading'),
                body: Center(child: CircularProgressIndicator()));
          } else if (Supabase.instance.client.auth.currentUser != null) {
            body = const NavManager(key: ValueKey('home'));
          } else {
            body = const LoginPage(key: ValueKey('login'));
          }

          return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250), child: body);
        });
  }
}
