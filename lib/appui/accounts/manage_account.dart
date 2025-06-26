import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/appui/components/edit_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ManageAccountForm extends StatefulWidget {
  final AccountWithAmount? initialAccount;

  const ManageAccountForm({super.key, this.initialAccount});

  @override
  State<ManageAccountForm> createState() => _ManageAccountFormState();
}

class _ManageAccountFormState extends State<ManageAccountForm> {
  final List<String> _validControllers = ['name', 'notes', 'priority'];
  final Map<String, TextEditingController> _controllers = {};

  Color? _selectedColor;

  AccountWithAmount? get initialAccount => widget.initialAccount;
  bool get isEditing => initialAccount != null;

  AccountsCompanion? _buildAccount() {
    final String? name = _controllers['name']?.text.trim();
    final String? notes = _controllers['notes']?.text.trim();
    final int? priority = int.tryParse(
      _controllers['priority']?.text.trim() ?? '',
    );

    if (name == null) return null;

    return AccountsCompanion(
      id: Value.absentIfNull(initialAccount?.account.id),
      name: Value(name),
      notes: Value(notes),
      priority: Value.absentIfNull(priority),
      color: Value.absentIfNull(_selectedColor),
    );
  }

  @override
  void initState() {
    super.initState();

    for (var id in _validControllers) {
      _controllers[id] = TextEditingController();
    }

    if (isEditing) {
      _controllers['name']!.text = initialAccount!.account.name;
      _controllers['notes']!.text = initialAccount!.account.notes ?? '';
      _controllers['priority']!.text =
          initialAccount!.account.priority?.toString() ?? '';

      _selectedColor = initialAccount!.account.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    String title;

    if (isEditing) {
      title = 'Edit account';
    } else {
      title = 'Create account';
    }

    return EditFormScreen(
      title: title,
      onConfirm: () async {
        final AccountsCompanion? newAccount = _buildAccount();
        final snackbarProvider = context.read<SnackbarProvider>();

        if (newAccount == null) {
          snackbarProvider.showSnackBar(
            SnackBar(
              content: Text(
                "Something went wrong.",
              ), // TODO: Make this more descriptive
            ),
          );
          return;
        }

        final db = context.read<AppDatabase>();

        Account account;

        try {
          if (isEditing) {
            account = await db.accountDao.updateAccount(newAccount);
          } else {
            account = await db.accountDao.createAccount(newAccount);
          }
        } on ArgumentError catch (e) {
          snackbarProvider.showSnackBar(SnackBar(content: Text(e.message)));
          return;
        }

        final AccountWithAmount withTotal = AccountWithAmount(
          account: account,
          income: initialAccount?.income ?? 0,
          expenses: initialAccount?.expenses ?? 0,
        );

        if (context.mounted) {
          Navigator.of(context).pop(withTotal);
        }
      },
      formFields: [
        TextInputEditField(
          label: 'Name',
          controller: _controllers['name'],
          validator: validateTitle,
        ),
        EditFieldRow(
          children: [
            Expanded(
              child: TextInputEditField(
                label: 'Priority',
                controller: _controllers['priority'],
                validator: (value) {
                  if (value == null || value.isEmpty) return null;

                  final checkedVal = int.tryParse(value.trim());

                  if (checkedVal == null) {
                    return 'Priority must be a number';
                  } else {
                    return null;
                  }
                },
                textInputType: TextInputType.numberWithOptions(),
                suffixIcon: IconButtonWithTooltip(
                  tooltipText:
                      'Defines the order in which accounts should appear. The top-priority account will appear first on the home page',
                ),
              ),
            ),
            ColorPickerEditField(
              label: 'Color',
              selectedColor: _selectedColor ?? Colors.white,
              onChanged: (color) => setState(() => _selectedColor = color),
            ),
          ],
        ),
        TextInputEditField(
          label: 'Notes',
          controller: _controllers['notes'],
          maxLines: 3,
        ),
      ],
    );
  }
}
