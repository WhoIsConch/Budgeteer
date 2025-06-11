import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/appui/components/nav_manager.dart';
import 'package:budget/providers/settings.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingAccountData {
  final AccountsCompanion account;
  final double initialAmount;

  const OnboardingAccountData(this.account, this.initialAmount);
}

class OnboardingManager extends StatefulWidget {
  const OnboardingManager({super.key});

  @override
  State<OnboardingManager> createState() => _OnboardingManagerState();
}

class _OnboardingManagerState extends State<OnboardingManager> {
  final _accountFormKey = GlobalKey<_OnboardingAccountState>();

  OnboardingAccountData? _accountData;
  String? _name;

  int currentPageIndex = 0;

  List<Widget> get onboardingPages => [
    OnboardingAccount(key: _accountFormKey, initialData: _accountData),
    OnboardingUserAccount(),
  ];

  void _onNextPressed() {
    // TODO: Switch this based on what currentPageIndex is.
    switch (currentPageIndex) {
      case 0:
        if (!(_accountFormKey.currentState?.validateForm() ?? false)) return;

        final OnboardingAccountData? accountData =
            _accountFormKey.currentState?.getAccount();

        if (accountData != null) {
          setState(() => _accountData = accountData);
        }
        break;
      case 1: // This should be the final step
        _onSubmit();
        break;
    }

    if (currentPageIndex < onboardingPages.length - 1) {
      setState(() => currentPageIndex += 1);
    }
  }

  void _onBackPressed() {
    if (currentPageIndex == 0) return;

    setState(() {
      currentPageIndex -= 1;
    });
  }

  void _onSubmit() async {
    final db = context.read<AppDatabase>();

    if (_accountData != null) {
      final account = await db.accountDao.createAccount(_accountData!.account);

      db.transactionDao.createTransaction(
        TransactionsCompanion(
          date: Value(DateTime.now()),
          title: Value('Initial Balance'),
          amount: Value(_accountData!.initialAmount),
          accountId: Value(account.id),
          type: Value(TransactionType.income),
        ),
      );

      if (_name != null) {
        Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'display_name': _name}),
        );
      }
    }

    if (!mounted) return;

    final settings = context.read<SettingsService>();

    settings.setSetting('_showTour', false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => NavManager(key: ValueKey('home'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(32.0),
        child: Row(
          children: [
            ElevatedButton(
              onPressed: currentPageIndex == 0 ? null : _onBackPressed,
              child: Text('Back', style: TextStyle(fontSize: 16)),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: _onNextPressed,
              child: Text(
                currentPageIndex == onboardingPages.length - 1
                    ? 'Finish'
                    : 'Next',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          // TODO: Make this slide instead of fade
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 100),
            child: onboardingPages[currentPageIndex],
          ),
        ),
      ),
    );
  }
}

class OnboardingUserAccount extends StatefulWidget {
  const OnboardingUserAccount({super.key});

  @override
  State<OnboardingUserAccount> createState() => OnboardingUserAccountState();
}

class OnboardingUserAccountState extends State<OnboardingUserAccount> {
  final TextEditingController controller = TextEditingController();

  String? getName() {
    return controller.text;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Tell us about yourself',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        SizedBox(height: 12.0),
        Text(
          'This information is used to personalize Budgeteer',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        SizedBox(height: 32),
        TextInputEditField(
          label: 'Your first name (optional)',
          controller: controller,
        ),
      ],
    );
  }
}

class OnboardingAccount extends StatefulWidget {
  final OnboardingAccountData? initialData;

  const OnboardingAccount({super.key, this.initialData});

  @override
  State<OnboardingAccount> createState() => _OnboardingAccountState();
}

class _OnboardingAccountState extends State<OnboardingAccount> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final amountController = TextEditingController();

  OnboardingAccountData? getAccount() {
    double? amount = double.tryParse(amountController.text);

    if (amount == null) return null;
    if (nameController.text.trim().isEmpty) return null;

    return OnboardingAccountData(
      AccountsCompanion(name: Value(nameController.text.trim())),
      amount,
    );
  }

  bool validateForm() {
    return _formKey.currentState?.validate() ?? false;
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      nameController.text = widget.initialData!.account.name.value;
      amountController.text = widget.initialData!.initialAmount.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Text(
            'Create your first account',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          SizedBox(height: 12.0),
          Text(
            'Accounts help track where your money is kept, like in a checking account or as cash',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 32),
          TextInputEditField(
            label: 'Account Name',
            controller: nameController,
            validator: validateTitle,
          ),
          SizedBox(height: 12.0),
          AmountEditField(
            label: 'Starting Balance',
            controller: amountController,
            allowZero: true,
          ),
        ],
      ),
    );
  }
}
