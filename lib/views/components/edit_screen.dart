import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class CustomInputFormField extends StatelessWidget {
  final String text;
  final TextEditingController? controller;
  final int? maxLines;
  final bool validate;

  const CustomInputFormField({
    super.key,
    required this.text,
    this.controller,
    this.maxLines,
    this.validate = false,
  });
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: text,
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      validator: validate ? validateTitle : null,
      maxLines: maxLines,
    );
  }
}

class CustomToggleFormField extends StatelessWidget {
  final String title;
  final ValueChanged<bool?> onChanged;
  final bool value;

  const CustomToggleFormField({
    super.key,
    required this.title,
    required this.onChanged,
    this.value = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          value: value,
          onChanged: onChanged,
        ),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Text(title, style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class CustomDatePickerFormField extends StatelessWidget {
  final String title;
  final DateTime selectedDate;
  final TextEditingController? controller;
  final ValueChanged<DateTime?> onChanged;

  const CustomDatePickerFormField({
    super.key,
    required this.title,
    required this.selectedDate,
    required this.onChanged,
    this.controller,
  });

  void _pickDate(context) async {
    final DateTime? newDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    );

    onChanged(newDate);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
        suffixIcon: Icon(
          Icons.calendar_today,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      onTap: () => _pickDate(context),
    );
  }
}

class CustomAmountFormField extends StatelessWidget {
  final String title;
  final TextEditingController? controller;

  const CustomAmountFormField({
    super.key,
    required this.title,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: title,
        prefixIcon: Icon(
          Icons.attach_money,
          color: Theme.of(context).colorScheme.primary,
        ),
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: const AmountValidator().validateAmount,
    );
  }
}

class CustomColorPickerFormField extends StatelessWidget {
  final String title;
  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  const CustomColorPickerFormField({
    super.key,
    required this.title,
    required this.selectedColor,
    required this.onChanged,
  });

  void _pickColor(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pick a color'),
            content: MaterialPicker(
              pickerColor: selectedColor,
              onColorChanged: onChanged,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pickColor(context),
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
                    color: selectedColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _pickColor(context),
                icon: Icon(Icons.arrow_drop_down),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomDropDownFormField<T> extends StatelessWidget {
  final String title;
  final ValueChanged<T?> onChanged;
  final TextEditingController? controller;
  final T? initialSelection;
  final FormFieldState? fieldState;

  final List<T?> values;
  final List<String> labels;
  final String? errorText;
  final String? helperText;

  const CustomDropDownFormField({
    super.key,
    required this.title,
    required this.onChanged,
    required this.values,
    required this.labels,
    this.initialSelection,
    this.controller,
    this.errorText,
    this.helperText,
    this.fieldState,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T?>(
      errorText: errorText,
      helperText: helperText,
      controller: controller,
      initialSelection: initialSelection,
      expandedInsets: EdgeInsets.zero,
      dropdownMenuEntries:
          values
              .map(
                (e) => DropdownMenuEntry(
                  value: e,
                  label: labels[values.indexOf(e)],
                ),
              )
              .toList(),
      label: Text(title),
      onSelected: (value) {
        onChanged(value);

        if (fieldState != null) fieldState!.didChange(value);
      },
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}

class HybridManagerButton extends StatelessWidget {
  final FormFieldState? formFieldState;
  final String? tooltip;
  final Icon icon;
  final dynamic Function()? onPressed;

  const HybridManagerButton({super.key, this.formFieldState, this.tooltip, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: IconButton(
        icon: icon,
        tooltip:tooltip,
        onPressed: () async {
          if (onPressed == null) return;

          dynamic result = onPressed!();

          if (result is Future) {
            result = await result;
          }

          if (result != null && formFieldState != null) {
            print("Change");
            formFieldState!.didChange(result);
          }
        }
      ));
  }
}

class EditFormScreen extends StatefulWidget {
  final String title;
  final Function() onConfirm;
  final List<Widget> formFields;

  const EditFormScreen({
    super.key,
    required this.title,
    required this.onConfirm,
    required this.formFields,
  });

  @override
  State<EditFormScreen> createState() => _EditFormScreenState();
}

class _EditFormScreenState extends State<EditFormScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_formKey.currentState!.validate()) widget.onConfirm();
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
              children: widget.formFields,
            ),
          ),
        ),
      ),
    );
  }
}
