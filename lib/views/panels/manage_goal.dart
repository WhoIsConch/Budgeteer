import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/providers/transaction_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
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
  final _formKey = GlobalKey<FormState>();

  final List<String> _validControllers = ['amount', 'name', 'notes'];
  DateTime _selectedDate = DateTime.now();
  double _currentAmount = 0;
  Color? _selectedColor;
  bool _isFinished = false;

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

  void _pickDate(context) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    );

    if (selectedDate != null) {
      setState(() => _selectedDate = selectedDate);
    }
  }

  void _updateAmount() => setState(
    () => _currentAmount = double.tryParse(_controllers['amount']!.text) ?? 0,
  );

  Widget _getMenuButton(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(-24, 0),
      menuChildren: [
        MenuItemButton(
          child: const Text('Delete'),
          onPressed:
              () => showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Delete goal?'),
                      content: const Text(
                        'Are you sure you want to delete this goal?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            final manager = DeletionManager(context);

                            manager.stageObjectsForDeletion<Goal>([
                              initialGoal!.goal.id,
                            ]);
                            Navigator.of(context)
                              ..pop()
                              ..pop();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              ),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, _) => IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          ),
    );
  }

  Value<String> getControllerValue(String id) =>
      _controllers[id] != null
          ? Value(_controllers[id]!.text)
          : const Value.absent();

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

      _selectedColor = initialGoal!.goal.color;
      _currentAmount = initialGoal!.goal.cost;
      _isFinished = initialGoal!.goal.isFinished;
    }

    _controllers = tempControllers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit goal' : 'Add goal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final goalDao = context.read<GoalDao>();
                final currentGoal = _buildGoal();

                try {
                  if (isEditing) {
                    goalDao.updateGoal(currentGoal);
                  } else {
                    goalDao.createGoal(currentGoal);
                  }

                  Navigator.of(context).pop();
                } catch (e) {
                  AppLogger().logger.e('Unable to save goal: $e');
                  context.read<SnackbarProvider>().showSnackBar(
                    const SnackBar(content: Text('Unable to save transaction')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Form(
            autovalidateMode: AutovalidateMode.onUnfocus,
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16.0,
              children: [
                Row(
                  spacing: 8.0,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _controllers['name'],
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: validateTitle,
                      ),
                    ),
                    if (isEditing) _getMenuButton(context),
                  ],
                ),
                Row(
                  spacing: 16.0,
                  children: [
                    Expanded(
                      child: TextFormField(
                        onChanged: (_) => _updateAmount(),
                        controller: _controllers['amount'],
                        decoration: InputDecoration(
                          labelText: 'Cost',
                          prefixIcon: Icon(
                            Icons.attach_money,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: const AmountValidator().validateAmount,
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date',
                          border: const OutlineInputBorder(),
                          suffixIcon: Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        controller: TextEditingController(
                          text: DateFormat('MM/dd/yyyy').format(_selectedDate),
                        ),
                        onTap: () => _pickDate(context),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _isFinished = !_isFinished),
                  child: Row(
                    children: [
                      Checkbox(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        value: _isFinished,
                        onChanged:
                            (value) =>
                                setState(() => _isFinished = value ?? false),
                      ),
                      Text(
                        'Mark as finished',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: _controllers['notes'],
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
