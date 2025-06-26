import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/services/providers/settings.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/models/enums.dart';
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
  final _personalFormKey = GlobalKey<_OnboardingUserAccountState>();

  OnboardingAccountData? _accountData;
  String? _name;

  int currentPageIndex = 0;

  List<Widget> get onboardingPages => [
    OnboardingUserAccount(key: _personalFormKey, initialData: _name),
    OnboardingAccount(key: _accountFormKey, initialData: _accountData),
    OnboardingInformation(key: ValueKey('onboardingInfo')),
  ];

  void _onNextPressed() {
    // TODO: Switch this based on what currentPageIndex is.
    switch (currentPageIndex) {
      case 0:
        setState(() {
          _name = _personalFormKey.currentState?.getName();
        });
        break;
      case 1:
        if (!(_accountFormKey.currentState?.validateForm() ?? false)) return;

        final OnboardingAccountData? accountData =
            _accountFormKey.currentState?.getAccount();

        if (accountData != null) {
          setState(() => _accountData = accountData);
        }
        break;
      case 2: // This should be the final step
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
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: {'full_name': _name}),
        );
      }
    }

    if (!mounted) return;

    final settings = context.read<SettingsService>();

    // Don't switch pages, since this should be handled by AuthWrapper
    settings.setSetting('_showTour', false);
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
            // Custom layout builder is necessary to top-align all items in the
            // stack to ensure scrollable ones don't get center-positioned and
            // cause the screen to jump
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class OnboardingHeader extends StatelessWidget {
  final String title;
  final String? description;

  const OnboardingHeader({super.key, required this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        if (description != null) SizedBox(height: 12.0),
        if (description != null)
          Text(description!, style: Theme.of(context).textTheme.bodyLarge),
        SizedBox(height: 32),
      ],
    );
  }
}

class OnboardingUserAccount extends StatefulWidget {
  final String? initialData;

  const OnboardingUserAccount({super.key, this.initialData});

  @override
  State<OnboardingUserAccount> createState() => _OnboardingUserAccountState();
}

class _OnboardingUserAccountState extends State<OnboardingUserAccount> {
  final TextEditingController controller = TextEditingController();

  String? getName() {
    return controller.text;
  }

  @override
  void initState() {
    super.initState();

    if (widget.initialData != null) {
      controller.text = widget.initialData!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OnboardingHeader(
          title: 'Tell us about yourself',
          description: 'This information is used to personalize Budgeteer',
        ),
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
          OnboardingHeader(
            title: 'Create your first account',
            description:
                'Accounts help track where your money is kept, like in a checking account or as cash',
          ),
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

class OnboardingInformation extends StatelessWidget {
  const OnboardingInformation({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          OnboardingHeader(
            title: 'Learn more about Budgeteer',
            description:
                'Discover the best ways to utilize features within the app',
          ),
          ExpandingHelpTile(
            title: 'Transactions',
            description:
                'Transactions are the most fundamental aspect of Budgeteer. They allow you to spend, receive, and transfer funds.',
          ),
          SizedBox(height: 8.0),
          ExpandingHelpTile(
            title: 'Accounts',
            description:
                'Accounts are used to track where your money is stored. For example, a new account may be created for a bank account, a physical wallet, or digital store.',
          ),
          SizedBox(height: 8.0),
          ExpandingHelpTile(
            title: 'Categories',
            description:
                'Categories can be considered "budgets" that help organize transactions into spending groups. You can limit the spending of a category to ensure you don\'t spend too much in a certain amount of time.',
          ),
          SizedBox(height: 8.0),
          ExpandingHelpTile(
            title: 'Goals',
            description:
                'A goal functions similarly to an account, but is used to track money being put toward a financial goal like buying something. While you still physically have the money put toward a goal, Budgeteer will ignore it as if it was already spent.',
          ),
        ],
      ),
    );
  }
}

class ExpandingHelpTile extends StatelessWidget {
  final String title;
  final String description;

  const ExpandingHelpTile({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        title: Text(title),
        expandedAlignment: Alignment.topLeft,
        childrenPadding: EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        children: [Text(description)],
      ),
    );
  }
}
