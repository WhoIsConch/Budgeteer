import 'dart:async';
import 'dart:math';

import 'package:budget/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/transaction_provider.dart';
import 'package:budget/tools/enums.dart';
import 'package:budget/tools/validators.dart';

class ManageCategoryDialog extends StatefulWidget {
  const ManageCategoryDialog(
      {super.key, this.mode = ObjectManageMode.add, this.category});

  final ObjectManageMode mode;
  final Category? category;

  @override
  State<ManageCategoryDialog> createState() => _ManageCategoryDialogState();
}

class _ManageCategoryDialogState extends State<ManageCategoryDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool allowNegatives = true;
  CategoryResetIncrement resetIncrement = CategoryResetIncrement.never;
  Color? selectedColor;

  CategoriesCompanion getCategory() {
    return CategoriesCompanion(
      id: Value.absentIfNull(widget.category?.id),
      name: Value(nameController.text),
      balance: Value.absentIfNull(double.tryParse(amountController.text)),
      resetIncrement: Value(resetIncrement),
      allowNegatives: Value(allowNegatives),
      color: Value.absentIfNull(selectedColor),
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.mode == ObjectManageMode.edit) {
      nameController.text = widget.category!.name;
      amountController.text =
          widget.category!.balance?.toStringAsFixed(2) ?? "0";
      allowNegatives = widget.category!.allowNegatives;
      resetIncrement = widget.category!.resetIncrement;
      selectedColor = widget.category!.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = "Create Category";

    // Random category hints for fun
    List<String> categoryHints = [
      "CD Collection",
      "Eating Out",
      "Phone Bill",
      "Video Games",
      "Entertainment",
      "Streaming Services",
      "ChatGPT Credits",
      "Clothes",
      "Car"
    ];

    Random random = Random();
    String categoryHint =
        categoryHints[random.nextInt(categoryHints.length - 1)];

    if (widget.category != null) {
      title = "Edit Category";
    }

    TextButton okButton = TextButton(
      child: const Text("Ok"),
      onPressed: () async {
        if (!_formKey.currentState!.validate()) {
          return;
        }

        final provider = Provider.of<AppDatabase>(context, listen: false);
        Category savedCategory;

        try {
          if (widget.mode == ObjectManageMode.edit) {
            // There is no way this shouldn't be a valid category with a valid
            // ID. If it isn't, I'll let the try-catch handle it for now.
            // I'll think of something else if it becomes a problem.
            savedCategory =
                await provider.updatePartialCategory(getCategory()) as Category;
          } else {
            savedCategory = await provider.createCategory(getCategory());
          }

          if (context.mounted) {
            Navigator.of(context).pop(savedCategory);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Failed to save transaction: $e")),
            );
          }
        }
      },
    );

    List<Widget> formActions;

    if (widget.mode == ObjectManageMode.add) {
      formActions = [okButton];
    } else {
      formActions = [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
                child: Text("Delete",
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                onPressed: () {
                  final provider =
                      Provider.of<TransactionProvider>(context, listen: false);
                  Category removedCategory = getCategory();

                  bool undoPressed = false;

                  Navigator.of(context).pop("");

                  // TODO: Make sure this works
                  provider.addPendingCategory(removedCategory);

                  scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
                  scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                          label: "Undo",
                          onPressed: () {
                            undoPressed = true;
                            provider.removePendingCategory(removedCategory);
                          }),
                      content: Text(
                          "Category \"${removedCategory.name}\" deleted")));

                  Timer(const Duration(seconds: 3, milliseconds: 250), () {
                    scaffoldMessengerKey.currentState!.hideCurrentSnackBar();

                    if (!undoPressed) {
                      provider.deleteCategory(removedCategory);
                      print("Removed");
                    }
                  });
                }),
            Row(
              children: [okButton],
            ),
          ],
        )
      ];
    }

    return Form(
      key: _formKey,
      child: AlertDialog(
        title:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ]),
        actions: formActions,
        content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                        labelText: "Category Name", hintText: categoryHint),
                    validator: validateTitle,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: false),
                      validator:
                          const AmountValidator(allowZero: true).validateAmount,
                      inputFormatters: [DecimalTextInputFormatter()],
                      controller: amountController,
                      decoration: const InputDecoration(
                          prefixText: "\$",
                          hintText: "500.00",
                          labelText: "Maximum Balance")),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: GestureDetector(
                      onTap: () => setState(
                        () => allowNegatives = !allowNegatives,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              semanticLabel: "Allow Negative Balance",
                              value: allowNegatives,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => allowNegatives = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text("Allow Negative Balance")
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Reset every", style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  DropdownMenu(
                    expandedInsets: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 16),
                    initialSelection: widget.category?.resetIncrement ??
                        CategoryResetIncrement.never,
                    dropdownMenuEntries: CategoryResetIncrement.values
                        .map(
                          (e) => DropdownMenuEntry(label: e.text, value: e),
                        )
                        .toList(),
                    onSelected: (value) {
                      if (value != null) {
                        setState(() => resetIncrement = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                          title: const Text("Pick a color"),
                          content: MaterialPicker(
                              pickerColor: selectedColor ?? Colors.white,
                              onColorChanged: (newColor) =>
                                  setState(() => selectedColor = newColor)),
                          actions: [
                            TextButton(
                              child: const Text("Ok"),
                              onPressed: () => Navigator.pop(context),
                            )
                          ]),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Color: ",
                            style: TextStyle(fontSize: 18),
                          ),
                          Expanded(
                            child: Container(
                                height: 30,
                                decoration: BoxDecoration(
                                    color: selectedColor ?? Colors.white,
                                    borderRadius: BorderRadius.circular(2))),
                          ),
                        ]),
                  ),
                ]),
          );
        }),
      ),
    );
  }
}
