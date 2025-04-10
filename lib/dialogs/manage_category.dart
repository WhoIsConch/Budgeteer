import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:budget/tools/api.dart';
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
  final dbHelper = DatabaseHelper();

  bool allowNegatives = true;
  CategoryResetIncrement resetIncrement = CategoryResetIncrement.never;
  Color? selectedColor;

  String? validateCategoryTitle(value) {
    String? initialCheck = validateTitle(value);

    if (widget.mode == ObjectManageMode.edit) {
      return initialCheck;
    }

    final provider = Provider.of<TransactionProvider>(context, listen: false);

    bool isUnique = provider.categories.indexWhere(
          (element) => element.name == value,
        ) ==
        -1;

    if (initialCheck == null && isUnique) {
      return null;
    } else if (!isUnique) {
      return "Category already exists";
    } else {
      return initialCheck;
    }
  }

  Category getCategory() {
    return Category(
      id: widget.category?.id,
      name: nameController.text,
      balance: double.parse(amountController.text),
      resetIncrement: resetIncrement,
      allowNegatives: allowNegatives,
      color: selectedColor,
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.mode == ObjectManageMode.edit) {
      nameController.text = widget.category!.name;
      amountController.text = widget.category!.balance.toStringAsFixed(2);
      allowNegatives = widget.category!.allowNegatives;
      resetIncrement = widget.category!.resetIncrement;
      selectedColor = widget.category!.color!;
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

        final provider =
            Provider.of<TransactionProvider>(context, listen: false);
        Category savedCategory;

        try {
          if (widget.mode == ObjectManageMode.edit) {
            await provider.updateCategory(widget.category!, getCategory());
            savedCategory = getCategory();
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
                  int removedIndex = provider.categories
                      .indexWhere((e) => e.id == removedCategory.id);

                  bool undoPressed = false;

                  Navigator.of(context).pop("");

                  provider.removeCategoryFromList(removedIndex);

                  scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
                  scaffoldMessengerKey.currentState!.showSnackBar(SnackBar(
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                          label: "Undo",
                          onPressed: () {
                            undoPressed = true;

                            provider.insertCategoryToList(
                                removedIndex, removedCategory);
                          }),
                      content: Text(
                          "Category \"${removedCategory.name}\" deleted")));

                  Timer(const Duration(seconds: 3, milliseconds: 250), () {
                    scaffoldMessengerKey.currentState!.hideCurrentSnackBar();

                    if (!undoPressed) {
                      provider.removeCategory(removedCategory);
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
                    validator: validateCategoryTitle,
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
