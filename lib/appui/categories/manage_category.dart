import 'package:budget/models/database_extensions.dart';
import 'package:budget/providers/snackbar_provider.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/utils/tools.dart';
import 'package:budget/utils/validators.dart';
import 'package:budget/appui/components/edit_screen.dart';
import 'package:budget/appui/categories/view_category.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budget/utils/enums.dart';

class ManageCategoryDialog extends StatefulWidget {
  final bool returnResult;
  final CategoryWithAmount? category;

  const ManageCategoryDialog({
    super.key,
    this.category,
    this.returnResult = false,
  });

  @override
  State<ManageCategoryDialog> createState() => _ManageCategoryDialogState();
}

class _ManageCategoryDialogState extends State<ManageCategoryDialog> {
  final List<String> _validControllers = ['name', 'amount', 'notes'];

  bool _allowNegatives = true;
  CategoryResetIncrement _resetIncrement = CategoryResetIncrement.never;
  Color? _selectedColor;

  late final Map<String, TextEditingController> _controllers;

  CategoryWithAmount? get initialCategory => widget.category;
  bool get isEditing => initialCategory != null;

  CategoriesCompanion _buildCategory() {
    return CategoriesCompanion(
      id: Value.absentIfNull(widget.category?.category.id),
      name: Value(_controllers['name']!.text),
      balance: Value.absentIfNull(
        double.tryParse(_controllers['amount']!.text),
      ),
      notes:
          _controllers['notes']!.text.trim().isEmpty
              ? const Value.absent()
              : Value(_controllers['notes']!.text),
      resetIncrement: Value(_resetIncrement),
      allowNegatives: Value(_allowNegatives),
      color: Value.absentIfNull(_selectedColor),
    );
  }

  @override
  void initState() {
    super.initState();

    Map<String, TextEditingController> tempControllers = {};

    for (var id in _validControllers) {
      tempControllers[id] = TextEditingController();
    }

    if (isEditing) {
      var category = initialCategory!.category;

      tempControllers['name']!.text = category.name;
      tempControllers['amount']!.text =
          category.balance?.toStringAsFixed(2) ?? '0';
      tempControllers['notes']!.text = category.notes ?? '';

      _allowNegatives = category.allowNegatives;
      _resetIncrement = category.resetIncrement;
      _selectedColor = category.color;
    }

    _controllers = tempControllers;
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Create Category';

    if (widget.category != null) {
      title = 'Edit Category';
    }

    return EditFormScreen(
      title: title,
      onConfirm: () async {
        final partialCategory = _buildCategory();
        final db = context.read<AppDatabase>();

        Category newCategory;

        try {
          if (isEditing) {
            newCategory = await db.categoryDao.updateCategory(partialCategory);
          } else {
            newCategory = await db.categoryDao.createCategory(partialCategory);
          }

          final CategoryWithAmount withAmount = CategoryWithAmount(
            category: newCategory,
            amount: initialCategory?.amount ?? 0,
          );

          if (context.mounted) {
            if (!widget.returnResult) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => CategoryViewer(categoryPair: withAmount),
                ),
              );
            } else {
              Navigator.of(context).pop(withAmount);
            }
          }
        } catch (e) {
          AppLogger().logger.e('Unable to save category: $e');
          if (!context.mounted) return;

          context.read<SnackbarProvider>().showSnackBar(
            const SnackBar(content: Text('Unable to save category')),
          );
        }
      },
      formFields: [
        Row(
          spacing: 16.0,
          children: [
            Expanded(
              child: TextInputEditField(
                label: 'Name',
                controller: _controllers['name'],
                validator: validateTitle,
              ),
            ),
            ColorPickerEditField(
              label: 'Color',
              selectedColor: _selectedColor ?? Colors.white,
              onChanged: (color) => setState(() => _selectedColor = color),
            ),
          ],
        ),
        Row(
          spacing: 16.0,
          children: [
            Expanded(
              child: AmountEditField(
                label: 'Amount',
                controller: _controllers['amount'],
              ),
            ),
            Expanded(
              child: DropdownEditField<CategoryResetIncrement>(
                initialSelection: _resetIncrement,
                label: 'Reset',
                onChanged:
                    (value) => setState(
                      () =>
                          _resetIncrement =
                              value ?? CategoryResetIncrement.never,
                    ),
                values: CategoryResetIncrement.values,
                labels:
                    CategoryResetIncrement.values
                        .map((v) => v.capitalizedName())
                        .toList(),
              ),
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
