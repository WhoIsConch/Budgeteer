import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

enum FieldType { title, multiline, amount, date, color, toggle, dropdown }

class DropdownFieldData<T> {
  final List<T> values;
  final List<String> labels;
  final String? errorText;
  final String? helperText;

  const DropdownFieldData({
    required this.values,
    required this.labels,
    this.errorText,
    this.helperText,
  });
}

class FieldData<T> {
  final String title;
  final FieldType type;
  final TextEditingController? controller;
  final ValueChanged<T?> onChanged;
  final T? defaultValue;
  final DropdownFieldData<T>? dropdownData;
  final bool enabled;

  const FieldData({
    required this.title,
    required this.type,
    required this.onChanged,
    this.controller,
    this.defaultValue,
    this.dropdownData,
    this.enabled = true,
  });
}

class VariableFormField<T> extends StatelessWidget {
  final FieldData<T> fieldData;

  const VariableFormField({super.key, required this.fieldData});

  void _pickDate(context, FieldData<DateTime> data) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: data.defaultValue ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    );

    data.onChanged(selectedDate);
  }

  void _pickColor(BuildContext context, FieldData<Color> data) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pick a color'),
            content: MaterialPicker(
              pickerColor: data.defaultValue ?? Colors.white,
              onColorChanged: data.onChanged,
            ),
            actions: [
              TextButton(
                child: const Text('Ok'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  Widget _getTitleBox(BuildContext context, FieldData<String> data) =>
      TextFormField(
        enabled: data.enabled,
        controller: data.controller,
        decoration: InputDecoration(
          labelText: data.title,
          border: OutlineInputBorder(),
        ),
        validator: validateTitle,
      );

  Widget _getMultilineTextBox(BuildContext context, FieldData<String> data) =>
      TextFormField(
        enabled: data.enabled,
        controller: data.controller,
        decoration: InputDecoration(
          labelText: data.title,
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        maxLines: 3,
        textInputAction: TextInputAction.done,
      );

  Widget _getToggleItem(BuildContext context, FieldData<bool> data) =>
      GestureDetector(
        onTap: () => data.onChanged,
        child: Row(
          children: [
            Checkbox(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: data.defaultValue ?? false,
              onChanged: data.onChanged,
            ),
            Text(data.title, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      );

  Widget _getDatePicker(BuildContext context, FieldData<DateTime> data) =>
      TextFormField(
        enabled: data.enabled,
        readOnly: true,
        decoration: InputDecoration(
          labelText: data.title,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(
            Icons.calendar_today,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        controller: data.controller,
        onTap: () => _pickDate(context, data),
      );

  Widget _getAmountBox(BuildContext context, FieldData<String> data) =>
      TextFormField(
        enabled: data.enabled,
        onChanged: data.onChanged,
        controller: data.controller,
        decoration: InputDecoration(
          labelText: data.title,
          prefixIcon: Icon(
            Icons.attach_money,
            color: Theme.of(context).colorScheme.primary,
          ),
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: const AmountValidator().validateAmount,
      );

  Widget _getColorPicker(BuildContext context, FieldData<Color> data) =>
      GestureDetector(
        onTap: data.enabled ? () => _pickColor(context, data) : () {},
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Padding(
            padding: EdgeInsets.all(4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.defaultValue ?? Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _pickColor(context, data),
                  icon: Icon(Icons.arrow_drop_down),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _getDropdownMenu(BuildContext context, FieldData<T> data) =>
      DropdownMenu<T>(
        errorText: data.dropdownData!.errorText,
        helperText: data.dropdownData!.helperText,
        enabled: data.enabled,
        controller: data.controller,
        initialSelection: data.defaultValue,
        expandedInsets: EdgeInsets.zero,
        dropdownMenuEntries:
            data.dropdownData!.values
                .map(
                  (e) => DropdownMenuEntry(
                    value: e,
                    label:
                        data.dropdownData!.labels[data.dropdownData!.values
                            .indexOf(e)],
                  ),
                )
                .toList(),
        label: Text(data.title),
        onSelected: data.onChanged,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      );

  @override
  Widget build(BuildContext context) => switch (fieldData.type) {
    FieldType.title => _getTitleBox(context, fieldData as FieldData<String>),
    FieldType.multiline => _getMultilineTextBox(
      context,
      fieldData as FieldData<String>,
    ),
    FieldType.date => _getDatePicker(context, fieldData as FieldData<DateTime>),
    FieldType.toggle => _getToggleItem(context, fieldData as FieldData<bool>),
    FieldType.amount => _getAmountBox(context, fieldData as FieldData<String>),
    FieldType.color => _getColorPicker(context, fieldData as FieldData<Color>),
    FieldType.dropdown => _getDropdownMenu(context, fieldData),
  };
}

class TestEditScreen extends StatelessWidget {
  const TestEditScreen({super.key});

  void _printCallback(dynamic value) => print(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            spacing: 8.0,
            children: [
              VariableFormField<String>(
                fieldData: FieldData(
                  title: "Title",
                  type: FieldType.title,
                  onChanged: _printCallback,
                ),
              ),
              VariableFormField<String>(
                fieldData: FieldData(
                  title: "Multiline",
                  type: FieldType.multiline,
                  onChanged: _printCallback,
                ),
              ),
              VariableFormField<DateTime>(
                fieldData: FieldData(
                  title: "Date",
                  type: FieldType.date,
                  onChanged: _printCallback,
                ),
              ),
              VariableFormField<bool>(
                fieldData: FieldData(
                  title: "Toggle",
                  type: FieldType.toggle,
                  defaultValue: true,
                  onChanged: _printCallback,
                ),
              ),
              VariableFormField<String>(
                fieldData: FieldData(
                  title: "Amount",
                  enabled: false,
                  type: FieldType.amount,
                  onChanged: _printCallback,
                ),
              ),
              VariableFormField<Color>(
                fieldData: FieldData(
                  title: "Color",
                  type: FieldType.color,
                  onChanged: _printCallback,
                ),
              ),
              VariableFormField<String>(
                fieldData: FieldData(
                  title: "Dropdown",
                  type: FieldType.dropdown,
                  onChanged: _printCallback,
                  dropdownData: DropdownFieldData(
                    values: ["One", "Two"],
                    labels: ["One", "Two"],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
