import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class PickerFieldResponse<T> {
  // Used so we can differentiate between when a field purposely returns a null
  // value (when it's clearing the field) or when the result is null due to a
  // user action (e.g. closing the window)
  final T? value;
  final bool cancelled;

  const PickerFieldResponse(this.value, {this.cancelled = false});
}

class IconButtonWithTooltip extends StatefulWidget {
  final String tooltipText;
  final bool isFocused;
  final Color? color;

  const IconButtonWithTooltip({
    super.key,
    required this.tooltipText,
    this.isFocused = false,
    this.color,
  });

  @override
  State<IconButtonWithTooltip> createState() => _IconButtonWithTooltipState();
}

class _IconButtonWithTooltipState extends State<IconButtonWithTooltip> {
  // TODO: Make this disappear on outside tap
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  Alignment _followerAnchor = Alignment.bottomCenter;
  Alignment _targetAnchor = Alignment.topCenter;

  bool get _isTooltipVisible => _overlayEntry != null;

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
  }

  void _removeTooltip() {
    // Null check since isTooltipVisible already checks for null
    if (_isTooltipVisible) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void _updateTooltipAlignment() {
    final renderBox = context.findRenderObject() as RenderBox;
    final buttonSize = renderBox.size;

    // localToGlobal gives the top-left corner of the button in screen coordinates
    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the horizontal center of the button
    final buttonCenter = buttonPosition.dx + buttonSize.width / 2;

    // Check if aligning to the left would cause an overflow
    // a little buffer (16.0) is added for padding
    if (buttonCenter < screenWidth / 3) {
      setState(() {
        _targetAnchor = Alignment.bottomLeft;
        _followerAnchor = Alignment.topLeft;
      });
    } else if (buttonCenter > screenWidth * 2 / 3) {
      // Button is on the right side
      setState(() {
        _targetAnchor = Alignment.bottomRight;
        _followerAnchor = Alignment.topRight;
      });
    } else {
      // Button is somewhere in the center
      setState(() {
        _targetAnchor = Alignment.bottomCenter;
        _followerAnchor = Alignment.topCenter;
      });
    }
  }

  void _showTooltip() {
    _updateTooltipAlignment();

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry() => OverlayEntry(
    builder:
        (context) => Stack(
          children: [
            Positioned.fill(
              // In case outside of the tooltip is tapped
              child: GestureDetector(
                onTap: _removeTooltip,
                child: Container(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              // offset: Offset(0, 0),
              followerAnchor: _followerAnchor,
              targetAnchor: _targetAnchor,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      widget.tooltipText,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
  );

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        icon: Icon(Icons.help, color: widget.color),
        tooltip: _isTooltipVisible ? '' : 'Tap for info',
        onPressed: _toggleTooltip,
      ),
    );
  }
}

class TextInputEditField extends StatelessWidget {
  final String label;
  final TextInputType? textInputType;
  final TextEditingController? controller;
  final int? maxLines;
  final String? Function(String?)? validator;
  final String? helpText;
  final Widget? suffixIcon;

  const TextInputEditField({
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
        suffixIcon: suffixIcon,
      ),
      validator: validator,
      maxLines: maxLines,
    );
  }
}

class ToggleEditField extends StatelessWidget {
  final String label;
  final ValueChanged<bool?> onChanged;
  final bool value;

  const ToggleEditField({
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

class DatePickerEditField extends StatefulWidget {
  final String label;
  final DateTime? selectedDate;
  final TextEditingController? controller;
  final ValueChanged<PickerFieldResponse<DateTime>> onChanged;
  final bool isNullable;

  const DatePickerEditField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onChanged,
    this.controller,
    this.isNullable = false,
  });

  @override
  State<DatePickerEditField> createState() => _DatePickerEditFieldState();
}

class _DatePickerEditFieldState extends State<DatePickerEditField> {
  void _pickDate(context) async {
    final DateTime? newDate = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    );

    widget.onChanged(PickerFieldResponse(newDate, cancelled: newDate == null));
  }

  @override
  void initState() {
    super.initState();

    // Ensure the widget can't be non-nullable while having a null value
    if (!widget.isNullable && widget.selectedDate == null) {
      widget.onChanged(PickerFieldResponse(DateTime.now()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.isNullable && widget.selectedDate != null)
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => widget.onChanged(PickerFieldResponse(null)),
                ),
              ),
            if (!widget.isNullable || widget.selectedDate == null)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(
                  Icons.calendar_today,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
      onTap: () => _pickDate(context),
    );
  }
}

class AmountEditField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final bool allowZero;

  const AmountEditField({
    super.key,
    required this.label,
    required this.controller,
    this.allowZero = false,
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
      validator: AmountValidator(allowZero: allowZero).validateAmount,
    );
  }
}

class ColorPickerEditField extends StatelessWidget {
  final String label;
  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  const ColorPickerEditField({
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

class DropdownEditField<T> extends StatelessWidget {
  final String label;
  final ValueChanged<T?> onChanged;
  final TextEditingController? controller;
  final T? initialSelection;
  final FormFieldState? fieldState;
  final bool enabled;

  final List<T?> values;
  final List<String> labels;
  final String? errorText;
  final String? helperText;

  const DropdownEditField({
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
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T?>(
      enabled: enabled,
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

class EditFieldRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const EditFieldRow({super.key, required this.children, this.spacing = 16.0});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: spacing,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
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
