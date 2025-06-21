import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/appui/goals/view_goal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ManageGoalPage extends StatefulWidget {
  final bool returnResult;
  final GoalWithAmount? initialGoal;

  const ManageGoalPage({
    super.key,
    this.initialGoal,
    this.returnResult = false,
  });

  @override
  State<ManageGoalPage> createState() => _ManageGoalPageState();
}

class _ManageGoalPageState extends State<ManageGoalPage> {
  final List<String> _validControllers = ['amount', 'name', 'notes', 'date'];

  bool _isFinished = false;
  DateTime? _selectedDate;
  Color? _selectedColor;

  late final Map<String, TextEditingController> _controllers;

  GoalWithAmount? get initialGoal => widget.initialGoal;
  bool get isEditing => widget.initialGoal != null;

  GoalsCompanion _buildGoal() => GoalsCompanion(
    id: Value.absentIfNull(initialGoal?.goal.id),
    name: getControllerValue('name'),
    cost: Value(double.parse(_controllers['amount']!.text)),
    dueDate: Value(_selectedDate),
    notes: getControllerValue('notes'),
    color: Value.absentIfNull(_selectedColor),
    isDeleted: Value(false),
    isArchived: Value(_isFinished),
  );

  Value<String> getControllerValue(String id) =>
      _controllers[id] != null
          ? Value(_controllers[id]!.text.trim())
          : const Value.absent();

  void _updateDateControllerText() {
    if (_selectedDate == null) {
      _controllers['date']!.text = '';
      return;
    }

    _controllers['date']!.text = DateFormat(
      'MM/dd/yyyy',
    ).format(_selectedDate!);
  }

  @override
  void initState() {
    super.initState();

    Map<String, TextEditingController> tempControllers = {};

    for (var id in _validControllers) {
      tempControllers[id] = TextEditingController();
    }

    if (isEditing) {
      tempControllers['name']!.text = initialGoal!.goal.name;
      tempControllers['notes']!.text = initialGoal!.goal.notes ?? '';
      tempControllers['amount']!.text = initialGoal!.goal.cost.toStringAsFixed(
        2,
      );

      _selectedDate = initialGoal!.goal.dueDate ?? DateTime.now();
      _selectedColor = initialGoal!.goal.color;
      _isFinished = initialGoal!.goal.isArchived;
    }

    _controllers = tempControllers;
    _updateDateControllerText();
  }

  @override
  Widget build(BuildContext context) {
    return EditFormScreen(
      title: isEditing ? 'Edit Goal' : 'Create goal',
      onConfirm: () async {
        final db = context.read<AppDatabase>();
        final currentGoal = _buildGoal();

        Goal newGoal;

        try {
          if (isEditing) {
            newGoal = await db.goalDao.updateGoal(currentGoal);
          } else {
            newGoal = await db.goalDao.createGoal(currentGoal);
          }

          final GoalWithAmount goalPair = GoalWithAmount(
            goal: newGoal,
            expenses: initialGoal?.expenses ?? 0,
            income: initialGoal?.income ?? 0,
          );

          if (context.mounted) {
            if (!widget.returnResult) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => GoalViewer(initialGoalPair: goalPair),
                ),
              );
            } else {
              Navigator.of(context).pop(goalPair);
            }
          }
        } catch (e) {
          AppLogger().logger.e('Unable to save goal: $e');

          if (!context.mounted) return;

          context.read<SnackbarProvider>().showSnackBar(
            const SnackBar(content: Text('Unable to save goal')),
          );
        }
      },
      formFields: [
        EditFieldRow(
          children: [
            Expanded(
              child: TextInputEditField(
                controller: _controllers['name'],
                label: 'Name',
                validator: validateTitle,
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
        EditFieldRow(
          children: [
            Expanded(
              child: DatePickerEditField(
                selectedDate: _selectedDate,
                label: 'Date',
                controller: _controllers['date'],
                onChanged: (response) {
                  if (response.cancelled) return;

                  setState(() {
                    _selectedDate = response.value;
                    _updateDateControllerText();
                  });
                },
                isNullable: true,
              ),
            ),
            ColorPickerEditField(
              label: 'Color',
              selectedColor: _selectedColor ?? Colors.white,
              onChanged: (color) => setState(() => _selectedColor = color),
            ),
          ],
        ),
        ToggleEditField(
          label: 'Mark as finished',
          value: _isFinished,
          onChanged: (_) => setState(() => _isFinished = !_isFinished),
        ),
        TextInputEditField(
          label: 'Notes (optional)',
          controller: _controllers['notes'],
          maxLines: 3,
        ),
      ],
    );
  }
}
