import 'package:budget/models/database_extensions.dart';
import 'package:budget/services/app_database.dart';
import 'package:budget/views/panels/manage_category.dart';
import 'package:budget/utils/enums.dart';
import 'package:budget/utils/validators.dart';
import 'package:flutter/material.dart';

class CategoryDropdown extends StatelessWidget {
  CategoryDropdown({
    super.key,
    required this.categories,
    required this.onChanged,
    required this.selectedCategory,
    required this.selectedCategoryTotal,
    this.onDeleted,
    this.showExpanded = true,
    this.transactionDate,
    this.isLoading = false,
  });

  final List<CategoryWithAmount> categories;
  final bool isLoading;
  final double selectedCategoryTotal;
  final Function(CategoryWithAmount?) onChanged;
  final Function? onDeleted;
  final CategoryWithAmount? selectedCategory;
  final DateTime? transactionDate;
  final TextEditingController categoryController = TextEditingController();
  final bool showExpanded;

  bool get shouldShowExpanded => showExpanded && selectedCategory != null;

  Color getDividerColor(BuildContext context) =>
      selectedCategory?.category.color ?? Theme.of(context).dividerColor;

  @override
  Widget build(BuildContext context) {
    if (selectedCategory == null || selectedCategory!.category.name.isEmpty) {
      categoryController.text = "No Category";
    } else {
      categoryController.text = selectedCategory!.category.name;
    }

    List<DropdownMenuEntry<String>> dropdownEntries =
        categories
            .map<DropdownMenuEntry<String>>(
              (CategoryWithAmount cat) => DropdownMenuEntry(
                value: cat.category.id,
                label: cat.category.name,
              ),
            )
            .toList();

    dropdownEntries.add(
      const DropdownMenuEntry<String>(value: "", label: "No Category"),
    );

    DropdownMenu menu = DropdownMenu<String>(
      enabled: !isLoading,
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
      initialSelection: selectedCategory?.category.name ?? "",
      controller: categoryController,
      requestFocusOnTap: true,
      label: const Text('Category'),
      expandedInsets: EdgeInsets.zero,
      onSelected: (String? categoryId) {
        if (categoryId == null || categoryId.isEmpty) {
          onChanged(null);
          return;
        }

        // This should usually be either a list of 1 or 0, so we use firstOrNull
        onChanged(
          categories.where((e) => e.category.id == categoryId).firstOrNull,
        );
      },
      dropdownMenuEntries: dropdownEntries,
    );

    // This decoration has a single bottom border for when the category selector
    // is showing category information. The rest of the border is constructed by
    // its outer container
    BoxDecoration jointBoxDecoration = BoxDecoration(
      border: Border(
        bottom: BorderSide(width: 1, color: getDividerColor(context)),
      ),
    );

    // This is the inner, first-row container that holds the category dropdown
    // and add/edit button
    Container categorySelector = Container(
      height: 56,
      decoration: shouldShowExpanded ? jointBoxDecoration : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: menu,
            ),
          ),
          Container(width: 1, height: 56, color: getDividerColor(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: IconButton(
              icon:
                  isLoading
                      ? const CircularProgressIndicator()
                      : selectedCategory == null
                      ? const Icon(Icons.add)
                      : const Icon(Icons.edit),
              onPressed: () async {
                final result = await showDialog(
                  context: context,
                  builder:
                      (context) =>
                          ManageCategoryDialog(category: selectedCategory),
                ).then(
                  (value) =>
                      value == true && onDeleted != null
                          ? onDeleted!()
                          : value is CategoryWithAmount
                          ? onChanged(value)
                          : null,
                );

                if (result is String && result.isEmpty) {
                  onChanged(null);
                } else if (result is CategoryWithAmount) {
                  onChanged(result);
                }
              },
            ),
          ),
        ],
      ),
    );

    List<Widget> columnChildren = [categorySelector];

    String balance = formatAmount(selectedCategoryTotal.abs(), exact: true);

    // The rest of the column children will be the category information
    // if the expanded view is up
    if (shouldShowExpanded) {
      columnChildren.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
          child: Text(
            "Balance: ${selectedCategoryTotal < 0 ? "-" : ""}\$$balance",
            style:
                selectedCategoryTotal < 0 &&
                        !selectedCategory!.category.allowNegatives
                    ? TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.error,
                    )
                    : const TextStyle(fontSize: 18),
          ),
        ),
      );

      columnChildren.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            (selectedCategory?.category.resetIncrement !=
                    CategoryResetIncrement.never
                ? "Resets in ${selectedCategory?.category.getTimeUntilNextReset(fromDate: transactionDate)}"
                : "Amount doesn't reset"),
          ),
        ),
      );
    }

    // This outer container shows the rest of the selector's border. Won't be
    // visible unless the container is expanded
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(width: 1, color: getDividerColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columnChildren,
      ),
    );
  }
}
