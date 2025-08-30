import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/models/enums.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/services/providers/snackbar_provider.dart';
import 'package:budget/utils/validators.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

typedef Transfer = (Transaction, Transaction);
typedef HydratedTransfer = (HydratedTransaction, HydratedTransaction);

class ManageTransferPage extends StatefulWidget {
  final bool returnResult;
  final Transfer? initialTransfer;

  const ManageTransferPage({
    super.key,
    this.initialTransfer,
    this.returnResult = false,
  });

  @override
  State<ManageTransferPage> createState() => ManageTransferPageState();
}

class ManageTransferPageState extends State<ManageTransferPage> {
  final List<String> _validControllers = [
    'title',
    'amount',
    'notes',
    'date',
    'goal1',
    'account1',
    'goal2',
    'account2',
  ];

  late final Map<String, TextEditingController> _controllers;

  DateTime _selectedDate = DateTime.now();
  // Make the list non-growable for memory purposes
  List<ContainerWithAmount?> _selectedPair = List.filled(
    2,
    null,
    growable: false,
  );

  bool _canSubmit() =>
      _selectedPair.any((i) => i != null) &&
      validateTitle(_controllers['title']!.text) == null &&
      AmountValidator(
            allowZero: false,
          ).validateAmount(_controllers['amount']!.text) ==
          null;

  void _onFinish() async {
    if (!_canSubmit()) return;

    final dao = context.read<AppDatabase>().transactionDao;

    var transaction1 = TransactionsCompanion(
      title: Value(_controllers['title']!.text),
      date: Value(_selectedDate),
      amount: Value(double.parse(_controllers['amount']!.text)),
      type: Value(TransactionType.expense),
    );

    if (_selectedPair[0] is AccountWithAmount) {
      transaction1 = transaction1.copyWith(
        accountId: Value(_selectedPair[0]!.objectId),
      );
    } else {
      transaction1 = transaction1.copyWith(
        goalId: Value(_selectedPair[0]!.objectId),
      );
    }

    Transaction? transaction1complete;

    if (widget.initialTransfer != null) {
      await dao.updateTransaction(
        transaction1.copyWith(id: Value(widget.initialTransfer!.$1.id)),
      );
    } else {
      transaction1complete = await dao.createTransaction(transaction1);
    }

    var transaction2 = TransactionsCompanion(
      title: Value(_controllers['title']!.text),
      date: Value(_selectedDate),
      amount: Value(double.parse(_controllers['amount']!.text)),
      transferWith: Value.absentIfNull(transaction1complete?.id),
      type: Value(TransactionType.income),
    );

    if (_selectedPair[1] is AccountWithAmount) {
      transaction2 = transaction2.copyWith(
        accountId: Value(_selectedPair[1]!.objectId),
      );
    } else {
      transaction2 = transaction2.copyWith(
        goalId: Value(_selectedPair[1]!.objectId),
      );
    }

    if (widget.initialTransfer != null) {
      await dao.updateTransaction(
        transaction2.copyWith(id: Value(widget.initialTransfer!.$2.id)),
      );
    } else {
      final transaction2complete = await dao.createTransaction(transaction2);

      await dao.updateTransaction(
        TransactionsCompanion(
          id: Value(transaction1complete!.id),
          transferWith: Value(transaction2complete.id),
        ),
      );
    }

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  void _onObjectSelected(ContainerWithAmount object, int index) {
    setState(() {
      if (object is AccountWithAmount) {
        _controllers['goal${index + 1}']!.text = '';
      } else {
        _controllers['account${index + 1}']!.text = '';
      }

      _selectedPair[index] = object;
    });
  }

  void _loadPreselected() async {
    final db = context.read<AppDatabase>();
    bool hasError = false;

    final List<ContainerWithAmount?> pair = List.filled(
      2,
      null,
      growable: false,
    );

    if (widget.initialTransfer == null) return;

    // This code is repetitive. It could probably be shortened.
    if (widget.initialTransfer!.$1.accountId != null) {
      pair[0] =
          await db.accountDao
              .watchAccountById(widget.initialTransfer!.$1.accountId!)
              .first;
      _controllers['account1']!.text = pair[0]!.object.name;
    } else if (widget.initialTransfer!.$1.goalId != null) {
      pair[0] =
          await db.goalDao
              .watchGoalById(widget.initialTransfer!.$1.goalId!)
              .first;
      _controllers['goal1']!.text = pair[0]!.object.name;
    } else {
      hasError = true;
    }

    if (widget.initialTransfer!.$2.accountId != null) {
      pair[1] =
          await db.accountDao
              .watchAccountById(widget.initialTransfer!.$2.accountId!)
              .first;
      _controllers['account2']!.text = pair[1]!.object.name;
    } else if (widget.initialTransfer!.$2.goalId != null) {
      pair[1] =
          await db.goalDao
              .watchGoalById(widget.initialTransfer!.$2.goalId!)
              .first;
      _controllers['goal2']!.text = pair[1]!.object.name;
    } else {
      hasError = true;
    }

    if (hasError && mounted) {
      context.read<SnackbarProvider>().showSnackBar(
        SnackBar(
          content: Text('Something went wrong while loading this transfer'),
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() => _selectedPair = pair);
    }
  }

  @override
  void initState() {
    super.initState();

    final Map<String, TextEditingController> controllers = {};

    for (var key in _validControllers) {
      controllers[key] = TextEditingController();
    }

    _controllers = controllers;

    if (widget.initialTransfer != null) {
      final from = widget.initialTransfer!.$1;

      _selectedDate = from.date;
      _controllers['title']!.text = from.title;
      _controllers['amount']!.text = from.amount.toStringAsFixed(2);

      _loadPreselected();
    }

    _controllers['date']!.text = DateFormat('MM/dd/yyyy').format(_selectedDate);
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EditFormScreen(
      title:
          widget.initialTransfer == null ? 'Create Transfer' : 'Edit Transfer',
      onConfirm: _onFinish,
      formFields: [
        TextInputEditField(
          label: 'Title',
          controller: _controllers['title'],
          validator: validateTitle,
        ),
        EditFieldRow(
          children: [
            Expanded(
              child: DatePickerEditField(
                label: 'Date',
                controller: _controllers['date'],
                selectedDate: _selectedDate,
                onChanged: (resp) {
                  if (resp.cancelled || resp.value == null) return;

                  setState(() {
                    _selectedDate = resp.value!;
                    _controllers['date']!.text = DateFormat(
                      'MM/dd/yyyy',
                    ).format(_selectedDate);
                  });
                },
              ),
            ),
            Expanded(
              child: AmountEditField(
                label: 'Amount',
                controller: _controllers['amount'],
              ),
            ),
          ],
        ),
        ObjectSelectTile(
          title: 'From...',
          onSelected: (object) => _onObjectSelected(object, 0),
          initialObject: _selectedPair[0],
          accountController: _controllers['account1'],
          goalController: _controllers['goal1'],
        ),
        ObjectSelectTile(
          title: 'To...',
          onSelected: (object) => _onObjectSelected(object, 1),
          initialObject: _selectedPair[1],
          accountController: _controllers['account2'],
          goalController: _controllers['goal2'],
        ),
      ],
    );
  }
}

class ObjectSelectTile extends StatefulWidget {
  final String title;
  final void Function(ContainerWithAmount)? onSelected;
  final ContainerWithAmount? initialObject;
  final TextEditingController? accountController;
  final TextEditingController? goalController;

  const ObjectSelectTile({
    super.key,
    required this.title,
    this.onSelected,
    this.initialObject,
    this.accountController,
    this.goalController,
  });

  @override
  State<ObjectSelectTile> createState() => _ObjectSelectTileState();
}

class _ObjectSelectTileState extends State<ObjectSelectTile> {
  void _onChanged(ContainerWithAmount? value) {
    if (value == null) return;

    if (widget.onSelected != null) widget.onSelected!(value);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        title: Text(widget.title),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: FormField<AccountWithAmount?>(
              builder: (state) {
                return StreamBuilder(
                  stream:
                      context.read<AppDatabase>().accountDao.watchAccounts(),
                  builder: (context, snapshot) {
                    List<AccountWithAmount> data = [];

                    if (snapshot.hasData) data = snapshot.data!;

                    return DropdownEditField<AccountWithAmount>(
                      fieldState: state,
                      initialSelection:
                          widget.initialObject is AccountWithAmount
                              ? widget.initialObject as AccountWithAmount
                              : null,
                      label: 'Account',
                      values: data,
                      onChanged: _onChanged,
                      labels: data.map((e) => e.account.name).toList(),
                      controller: widget.accountController,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
            child: FormField<GoalWithAmount?>(
              builder: (state) {
                return StreamBuilder(
                  stream: context.read<AppDatabase>().goalDao.watchGoals(),
                  builder: (context, snapshot) {
                    List<GoalWithAmount> data = [];

                    if (snapshot.hasData) data = snapshot.data!;

                    return DropdownEditField<GoalWithAmount>(
                      fieldState: state,
                      initialSelection:
                          widget.initialObject is GoalWithAmount
                              ? widget.initialObject as GoalWithAmount
                              : null,
                      label: 'Goal',
                      values: data,
                      onChanged: _onChanged,
                      labels: data.map((e) => e.goal.name).toList(),
                      controller: widget.goalController,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
