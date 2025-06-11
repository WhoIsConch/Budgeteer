import 'package:auto_size_text/auto_size_text.dart';
import 'package:dynamic_system_colors/dynamic_system_colors.dart';
import 'package:flutter/material.dart';

class TextOverviewHeader extends StatelessWidget {
  final String? title;
  final String? description;
  final Color? textColor;

  const TextOverviewHeader({
    super.key,
    required this.title,
    required this.description,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 4.0,
      children: [
        if (title != null)
          Text(
            title!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall!.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (description != null)
          Text(
            description!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge!,
            softWrap: true,
          ),
      ],
    );
  }
}

class ProgressOverviewHeader extends StatelessWidget {
  final String? title;
  final String? description;
  final String? insidePrimary;
  final String? insideSecondary;
  final Color? foregroundColor;
  final double progress;

  const ProgressOverviewHeader({
    super.key,
    required this.progress,
    this.title,
    this.description,
    this.insidePrimary,
    this.insideSecondary,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final foreground = foregroundColor?.harmonizeWith(primary) ?? primary;
    final background = foreground.withAlpha(68);

    return Row(
      spacing: 20.0,
      children: [
        SizedBox(
          height: 125,
          width: 125,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 96,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (insidePrimary != null)
                      AutoSizeText(
                        insidePrimary!,
                        maxLines: 1,
                        minFontSize: 28,
                        style: Theme.of(context).textTheme.displaySmall!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    if (insideSecondary != null) Text(insideSecondary!),
                  ],
                ),
              ),
              SizedBox.expand(
                child: TweenAnimationBuilder<double>(
                  curve: Curves.easeInOutQuart,
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: Duration(milliseconds: 1000),
                  builder:
                      (context, value, _) => CircularProgressIndicator(
                        strokeWidth: 16,
                        value: value,
                        color: foreground,
                        backgroundColor: background,
                        strokeCap: StrokeCap.round,
                      ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              if (title != null)
                Text(
                  title!,
                  style: Theme.of(context).textTheme.displaySmall!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (description != null)
                Text(
                  description!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class PropertyAction {
  final String title;
  final Function() onPressed;

  const PropertyAction({required this.title, required this.onPressed});
}

class ObjectPropertyData {
  final IconData icon;
  final String title;
  final String description;
  final void Function()? action;
  final List<PropertyAction>? actionButtons;

  const ObjectPropertyData({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.actionButtons,
  });
}

class ObjectPropertiesList extends StatelessWidget {
  final List<ObjectPropertyData> properties;

  const ObjectPropertiesList({super.key, required this.properties});

  Widget _getListItem(
    BuildContext context,
    ObjectPropertyData property,
  ) => InkWell(
    borderRadius: BorderRadius.circular(8.0),
    onTap: property.action,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            spacing: 8.0,
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  property.icon,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      property.description,
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (property.action != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.chevron_right),
                ),
            ],
          ),
          if (property.actionButtons != null &&
              property.actionButtons!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8, right: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children:
                    property.actionButtons!
                        .map(
                          (d) => ElevatedButton(
                            onPressed: d.onPressed,
                            child: Text(d.title),
                          ),
                        )
                        .toList(),
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: properties.length,
          separatorBuilder:
              (context, index) =>
                  Divider(color: Theme.of(context).colorScheme.outline),
          itemBuilder:
              (context, index) => _getListItem(context, properties[index]),
        ),
      ),
    );
  }
}

class ViewerScreen extends StatelessWidget {
  final String title;
  final bool isArchived;

  final Widget header;
  final Widget properties;
  final Widget? body;

  final Function()? onEdit;
  final Function()? onDelete;
  final Function()? onArchive;

  const ViewerScreen({
    super.key,
    required this.title,
    required this.header,
    required this.properties,
    this.onEdit,
    this.onDelete,
    this.onArchive,
    this.isArchived = false,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];

    if (onEdit != null) {
      actions.add(IconButton(icon: Icon(Icons.edit), onPressed: onEdit!));
    }

    if (onDelete != null || onArchive != null) {
      actions.add(
        MenuAnchor(
          alignmentOffset: const Offset(-24, 0),
          menuChildren: [
            if (onArchive != null)
              MenuItemButton(
                child: Text(isArchived ? 'Unarchive' : 'Archive'),
                onPressed:
                    () => showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: Text(
                              "${isArchived ? 'Una' : 'A'}rchive item?",
                            ),
                            content: const Text(
                              "Archived items don't affect balances and statistics",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  onArchive!();
                                  Navigator.of(context).pop();
                                },
                                child: Text(
                                  "${isArchived ? 'Una' : 'A'}rchive",
                                ),
                              ),
                            ],
                          ),
                    ),
              ),
            if (onDelete != null)
              MenuItemButton(
                child: const Text('Delete'),
                onPressed:
                    () => showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Delete transaction?'),
                            content: const Text(
                              'Are you sure you want to delete this transaction?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  onDelete!();
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                    ),
              ),
          ],
          builder:
              (BuildContext context, MenuController controller, _) =>
                  IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                  ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          spacing: 28.0,
          children: [
            SizedBox(height: 24),
            header,
            SizedBox(height: 20),
            properties,
            if (body != null) body!,
          ],
        ),
      ),
    );
  }
}
