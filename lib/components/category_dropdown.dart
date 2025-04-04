import 'package:budget/components/transaction_form.dart';
import 'package:budget/tools/api.dart';
import 'package:budget/tools/enums.dart';
import 'package:flutter/material.dart';

class CategoryDropdown extends StatelessWidget {
  CategoryDropdown({
    super.key,
    required this.categories,
    required this.onChanged,
    required this.selectedCategory,
    required this.selectedCategoryTotal,
    this.showExpanded = true,
  });

  final List<Category> categories;
  final Function(Category?) onChanged;
  final Category? selectedCategory;
  final double? selectedCategoryTotal;
  final TextEditingController categoryController = TextEditingController();
  final bool showExpanded;

  bool get shouldShowExpanded => showExpanded && selectedCategory != null;

  @override
  Widget build(BuildContext context) {
    if (selectedCategory != null) {
      categoryController.text = selectedCategory!.name;
    }

    List<DropdownMenuEntry<String>> dropdownEntries = categories
        .map<DropdownMenuEntry<String>>((Category cat) => DropdownMenuEntry(
              value: cat.name,
              label: cat.name,
            ))
        .toList();

    dropdownEntries
        .add(const DropdownMenuEntry<String>(value: "", label: "No Category"));

    DropdownMenu menu = DropdownMenu<String>(
      inputDecorationTheme:
          const InputDecorationTheme(border: InputBorder.none),
      initialSelection: selectedCategory?.name ?? "",
      controller: categoryController,
      requestFocusOnTap: true,
      label: const Text('Category'),
      expandedInsets: EdgeInsets.zero,
      onSelected: (String? categoryName) {
        if (categoryName == null || categoryName.isEmpty) {
          onChanged(null);
          return;
        }

        // This should usually be either a list of 1 or 0, so we use firstOrNull
        onChanged(categories.where((e) => e.name == categoryName).firstOrNull);
      },
      dropdownMenuEntries: dropdownEntries,
    );

    // This decoration has a single bottom border for when the category selector
    // is showing category information. The rest of the border is constructed by
    // its outer container
    BoxDecoration jointBoxDecoration = BoxDecoration(
      border: Border(
          bottom: BorderSide(
        width: 1,
        color: Theme.of(context).dividerColor,
      )),
    );

    // This is the inner, first-row container that holds the category dropdown
    // and add/edit button
    Container categorySelector = Container(
      height: 64,
      decoration: shouldShowExpanded ? jointBoxDecoration : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4), child: menu)),
        Container(width: 1, height: 64, color: Theme.of(context).dividerColor),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: IconButton(
              icon: selectedCategory == null
                  ? const Icon(Icons.add)
                  : const Icon(Icons.edit),
              onPressed: () async {
                final result = await showDialog(
                    context: context,
                    builder: (context) => CategoryManageDialog(
                          category: selectedCategory,
                          mode: selectedCategory == null
                              ? ObjectManageMode.add
                              : ObjectManageMode.edit,
                        ));

                if (result is String && result.isEmpty) {
                  onChanged(null);
                } else if (result is Category) {
                  onChanged(result);
                }
              },
            )),
      ]),
    );

    List<Widget> columnChildren = [categorySelector];

    // The rest of the column children will be the category information
    // if the expanded view is up
    if (shouldShowExpanded) {
      columnChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
          child: Text(
              "Balance: ${selectedCategoryTotal != null && selectedCategoryTotal! < 0 ? "-" : ""}\$${selectedCategoryTotal?.abs().toStringAsFixed(2)}",
              style: selectedCategoryTotal != null &&
                      selectedCategoryTotal! < 0 &&
                      !selectedCategory!.allowNegatives
                  ? TextStyle(
                      fontSize: 18, color: Theme.of(context).colorScheme.error)
                  : const TextStyle(fontSize: 18)),
        ),
      );

      columnChildren.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
            (selectedCategory?.resetIncrement != CategoryResetIncrement.never
                ? "Resets in ${selectedCategory?.getTimeUntilNextReset()}"
                : "Amount doesn't reset")),
      ));
    }

    // This outer container shows the rest of the selector's border. Won't be
    // visible unless the container is expanded
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(width: 1, color: Theme.of(context).dividerColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columnChildren,
        ));
  }
}
