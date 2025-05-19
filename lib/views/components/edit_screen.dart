import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class IconButtonWithTooltip extends StatefulWidget {
  final String tooltipText;
  final bool isFocused;

  const IconButtonWithTooltip({super.key, required this.tooltipText, this.isFocused = false});

  @override
  State<IconButtonWithTooltip> createState() => _IconButtonWithTooltipState();
}

class _IconButtonWithTooltipState extends State<IconButtonWithTooltip> {
  // TODO: Make this disappear on outside tap
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isTooltipVisible = false;

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  void _toggleTooltip() {
    if (_isTooltipVisible) {
      _removeTooltip();
    } else {
      _showTooltip();
    }
    setState(() {
      _isTooltipVisible = !_isTooltipVisible;
    });
  }

  void _removeTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showTooltip() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry() => OverlayEntry(
    builder:
        (context) => Positioned(
          top: 50,
          left: 50,
          width: 250,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            // offset: Offset(0, 0),
            followerAnchor: Alignment.topCenter, // Make top-center of tooltip
            targetAnchor: Alignment.bottomCenter, // align with bottom-center of icon
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                  widget.tooltipText,
                  textAlign: TextAlign.center,
                )
              )
            )
          ),
        ),
  );

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: _layerLink, child: IconButton(
      icon: Icon(Icons.help, color: widget.isFocused ? Theme.of(context).colorScheme.primary : null),
      tooltip: _isTooltipVisible ? '' : 'Tap for info',
      onPressed: _toggleTooltip
    ));
  }
}

class CustomInputFormField extends StatelessWidget {
  final String label;
  final TextInputType? textInputType;
  final TextEditingController? controller;
  final int? maxLines;
  final String? Function(String?)? validator;
  final String? helpText;
  final Widget? suffixIcon;

  const CustomInputFormField({
    super.key,
    required this.label,
    this.controller,
    this.maxLines,
    this.validator,
    this.textInputType,
    this.helpText,
    this.suffixIcon,
  });
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: textInputType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
        suffixIcon: suffixIcon
      ),
      validator: validator,
      maxLines: maxLines,
    );
  }
}

class CustomToggleFormField extends StatelessWidget {
  final String label;
  final ValueChanged<bool?> onChanged;
  final bool value;

  const CustomToggleFormField({
    super.key,
    required this.label,
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
          child: Text(label, style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class CustomDatePickerFormField extends StatelessWidget {
  final String label;
  final DateTime selectedDate;
  final TextEditingController? controller;
  final ValueChanged<DateTime?> onChanged;

  const CustomDatePickerFormField({
    super.key,
    required this.label,
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
        labelText: label,
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
  final String label;
  final TextEditingController? controller;

  const CustomAmountFormField({
    super.key,
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      inputFormatters: [DecimalTextInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
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
  final String label;
  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  const CustomColorPickerFormField({
    super.key,
    required this.label,
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
          padding: EdgeInsets.all(3.0),
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
  final String label;
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
    required this.label,
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
      label: Text(label),
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
  final String? tooltip;
  final Icon icon;
  final dynamic Function()? onPressed;

  const HybridManagerButton({
    super.key,
    this.tooltip,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: IconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: () async {
          if (onPressed == null) return;

          onPressed!();
        },
      ),
    );
  }
}

class SegmentButtonData<T> {
  final String label;
  final T value;

  const SegmentButtonData({required this.label, required this.value});
}

class MultisegmentButton<T> extends StatelessWidget {
  final List<SegmentButtonData<T>> data;
  final ValueChanged<T>? onChanged;
  final T? selected;

  const MultisegmentButton({
    super.key,
    required this.data,
    this.selected,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      onSelectionChanged:
          onChanged != null ? (contents) => onChanged!(contents.first) : null,
      selected: {selected ?? data.first.value},
      segments:
          data
              .map((d) => ButtonSegment(value: d.value, label: Text(d.label)))
              .toList(),
    );
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
