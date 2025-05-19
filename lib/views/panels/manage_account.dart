import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/views/components/edit_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ManageAccountForm extends StatefulWidget {
  final AccountWithTotal? initialAccount;

  const ManageAccountForm({super.key, this.initialAccount});

  @override
  State<ManageAccountForm> createState() => _ManageAccountFormState();
}

class _ManageAccountFormState extends State<ManageAccountForm> {
  final List<String> _validControllers = ['name', 'notes'];
  final Map<String, TextEditingController> _controllers = {};

  Color? _selectedColor;

  AccountWithTotal? get initialAccount => widget.initialAccount;
  bool get isEditing => initialAccount != null;

  AccountsCompanion? _buildAccount() {
    final String? name = _controllers['name']?.text.trim();
    final String? notes = _controllers['notes']?.text.trim();

    if (name == null) return null;

    return AccountsCompanion(
      id: Value.absentIfNull(initialAccount?.account.id),
      name: Value(name),
      notes: Value(notes),
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

        if (newAccount == null) {
          context.read<SnackbarProvider>().showSnackBar(
            SnackBar(
              content: Text(
                "Something went wrong.",
              ), // TODO: Make this more descriptive
            ),
          );
        }

        final db = context.read<AppDatabase>();

        Account account;

        if (isEditing) {
          // bruh
          account = await db.accountDao.updateAccount(newAccount!);
        } else {
          account = await db.accountDao.createAccount(newAccount!);
        }

        final AccountWithTotal withTotal = AccountWithTotal(
          account: account,
          total: initialAccount?.total ?? 0,
        );

        if (context.mounted) {
          Navigator.of(context).pop(withTotal);
        }
      },
      formFields: [
        Row(
          spacing: 16.0,
          children: [
            Expanded(
              child: CustomInputFormField(
                label: 'Name',
                controller: _controllers['name'],
                validate: true,
              ),
            ),
            CustomColorPickerFormField(
              label: 'Color',
              selectedColor: _selectedColor ?? Colors.white,
              onChanged: (color) => setState(() => _selectedColor = color),
            ),
          ],
        ),
        CustomInputFormField(
          label: 'Notes',
          controller: _controllers['notes'],
          maxLines: 3,
        ),
      ],
    );
  }
}
