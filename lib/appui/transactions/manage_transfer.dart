import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';
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
    'goal',
    'account',
  ];

  late final Map<String, TextEditingController> _controllers;

  DateTime _selectedDate = DateTime.now();
  // Make the list non-growable for memory purposes
  final List<ContainerWithAmount?> _selectedPair = List.filled(
    2,
    null,
    growable: false,
  );

  HydratedTransfer? _hydratedTransfer;

  @override
  void initState() {
    super.initState();

    final Map<String, TextEditingController> controllers = {};

    for (var key in _validControllers) {
      controllers[key] = TextEditingController();
    }

    _controllers = controllers;
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
      onConfirm: () {},
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
          onSelected: (object) => setState(() => _selectedPair[0] = object),
        ),
        ObjectSelectTile(
          title: 'To...',
          onSelected: (object) => setState(() => _selectedPair[1] = object),
        ),
      ],
    );
  }
}

class ObjectSelectTile extends StatefulWidget {
  final String title;
  final void Function(ContainerWithAmount)? onSelected;

  const ObjectSelectTile({super.key, required this.title, this.onSelected});

  @override
  State<ObjectSelectTile> createState() => _ObjectSelectTileState();
}

class _ObjectSelectTileState extends State<ObjectSelectTile> {
  ContainerWithAmount? _selected;

  void _onChanged(ContainerWithAmount? value) {
    if (value == null) return;

    setState(() => _selected = value);

    if (widget.onSelected != null) widget.onSelected!(value);
  }

  @override
  Widget build(BuildContext context) {
    bool isAccountSelected = _selected is AccountWithAmount;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        title: Text(widget.title),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: StreamBuilder(
              stream: context.read<AppDatabase>().accountDao.watchAccounts(),
              builder: (context, snapshot) {
                List<AccountWithAmount> data = [];

                if (snapshot.hasData) data = snapshot.data!;

                return DropdownEditField<AccountWithAmount>(
                  enabled:
                      snapshot.hasData &&
                      (_selected == null || isAccountSelected),
                  label: 'Account',
                  values: data,
                  onChanged: _onChanged,
                  labels: data.map((e) => e.account.name).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
            child: StreamBuilder(
              stream: context.read<AppDatabase>().goalDao.watchGoals(),
              builder: (context, snapshot) {
                List<GoalWithAmount> data = [];

                if (snapshot.hasData) data = snapshot.data!;

                return DropdownEditField<GoalWithAmount>(
                  enabled: _selected == null || !isAccountSelected,
                  label: 'Goal',
                  values: data,
                  onChanged: _onChanged,
                  labels: data.map((e) => e.goal.name).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
