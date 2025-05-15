import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/views/components/edit_screen.dart';
import 'package:budget/views/panels/view_goal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ManageGoalPage extends StatefulWidget {
  const ManageGoalPage({super.key, this.initialGoal});

  final GoalWithAchievedAmount? initialGoal;

  @override
  State<ManageGoalPage> createState() => _ManageGoalPageState();
}

class _ManageGoalPageState extends State<ManageGoalPage> {
  final List<String> _validControllers = ['amount', 'name', 'notes', 'date'];

  bool _isFinished = false;
  DateTime _selectedDate = DateTime.now();
  Color? _selectedColor;

  late final Map<String, TextEditingController> _controllers;

  GoalWithAchievedAmount? get initialGoal => widget.initialGoal;
  bool get isEditing => widget.initialGoal != null;

  GoalsCompanion _buildGoal() => GoalsCompanion(
    id: Value.absentIfNull(initialGoal?.goal.id),
    name: getControllerValue('name'),
    cost: Value(double.parse(_controllers['amount']!.text)),
    dueDate: Value(_selectedDate),
    notes: getControllerValue('notes'),
    color: Value.absentIfNull(_selectedColor),
    isFinished: Value(_isFinished),
  );

  Value<String> getControllerValue(String id) =>
      _controllers[id] != null
          ? Value(_controllers[id]!.text)
          : const Value.absent();

  void _updateDateControllerText() {
    _controllers['date']!.text = DateFormat('MM/dd/yyyy').format(_selectedDate);
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
      _isFinished = initialGoal!.goal.isFinished;
    }

    _controllers = tempControllers;
    _updateDateControllerText();
  }

  @override
  Widget build(BuildContext context) {
    return EditFormScreen(
      title: 'Edit Goal',
      onConfirm: () async {
        final goalDao = context.read<GoalDao>();
        final currentGoal = _buildGoal();

        Goal newGoal;

        try {
          if (isEditing) {
            newGoal = await goalDao.updateGoal(currentGoal);
          } else {
            newGoal = await goalDao.createGoal(currentGoal);
          }

          if (context.mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (_) => GoalViewer(
                      goalPair: GoalWithAchievedAmount(
                        goal: newGoal,
                        achievedAmount: initialGoal?.achievedAmount ?? 0,
                      ),
                    ),
              ),
            );
          }
        } catch (e) {
          AppLogger().logger.e('Unable to save goal: $e');
          context.read<SnackbarProvider>().showSnackBar(
            const SnackBar(content: Text('Unable to save transaction')),
          );
        }
      },
      formFields: [
        Row(
          spacing: 8.0,
          children: [
            Expanded(
              child: CustomInputFormField(
                // key: const ValueKey('goal_name'),
                controller: _controllers['name'],
                text: 'Name',
                validate: true,
              ),
            ),
          ],
        ),
        Row(
          spacing: 16.0,
          children: [
            Expanded(
              child: CustomInputFormField(
                // key: const ValueKey('goal_amount'),
                text: 'Amount',
                controller: _controllers['amount'],
              ),
            ),
            Expanded(
              child: CustomDatePickerFormField(
                // key: const ValueKey('goal_date'),
                selectedDate: _selectedDate,
                title: 'Date',
                controller: _controllers['date'],
                onChanged: (selectedDate) {
                  if (selectedDate != null) {
                    setState(() {
                      _selectedDate = selectedDate;
                      _updateDateControllerText();
                    });
                  }
                },
              ),
            ),
          ],
        ),
        CustomToggleFormField(
          title: 'Mark as finished',
          value: _isFinished,
          onChanged: (_) => setState(() => _isFinished = !_isFinished),
        ),
        CustomInputFormField(
          // key: const ValueKey('goal_notes'),
          text: 'Notes (optional)',
          controller: _controllers['notes'],
          maxLines: 3,
        ),
      ],
    );
  }
}
