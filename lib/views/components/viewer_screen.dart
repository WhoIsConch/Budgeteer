import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

class TextOverviewHeader extends StatelessWidget {
  final Widget title;
  final Widget description;

  const TextOverviewHeader({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 8.0,
      children: [title, description],
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
    this.foregroundColor
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
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (insidePrimary != null) Text(
                    insidePrimary!,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  if (insideSecondary != null) Text(insideSecondary!),
                ],
              ),
              SizedBox.expand(
                child: TweenAnimationBuilder<double>(
                  curve: Curves.easeInOutQuart,
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: Duration(milliseconds: 1000),
                  builder: (context, value, _) => CircularProgressIndicator(
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            if (title != null) Text(title!, style: Theme.of(context).textTheme.displaySmall),
            if (description != null) Text(description!, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}

class ObjectPropertyData {
  final IconData icon;
  final String title;
  final String description;
  final Function()? action;

  const ObjectPropertyData({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
}

class ObjectPropertiesList extends StatelessWidget {
  final List<ObjectPropertyData> properties;

  const ObjectPropertiesList({super.key, required this.properties});

  Widget _getListItem(ObjectPropertyData property) => InkWell(
    onTap: property.action,
    child: Row(
      spacing: 8.0,
      children: [
        Padding(padding: EdgeInsets.all(8.0), child: Icon(property.icon)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              Text(
                property.description,
                style: TextStyle(fontSize: 16),
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
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: properties.length,
          separatorBuilder:
              (context, index) =>
                  Divider(color: Theme.of(context).colorScheme.outline),
          itemBuilder: (context, index) => _getListItem(properties[index]),
        ),
      ),
    );
  }
}

class ViewerScreen extends StatelessWidget {
  final String title;
  final bool isArchived;

  final Widget header;
  final Widget body;

  final Function()? onEdit;
  final Function()? onDelete;
  final Function()? onArchive;

  const ViewerScreen({
    super.key,
    required this.title,
    required this.header,
    required this.body,
    this.onEdit,
    this.onDelete,
    this.onArchive,
    this.isArchived = false,
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
                              onPressed: onArchive,
                              child: Text("${isArchived ? 'Una' : 'A'}rchive"),
                            ),
                          ],
                        ),
                  ),
            ),
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
                              onPressed: onDelete,
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
        child: Column(spacing: 28.0, children: [header, body]),
      ),
    );
  }
}
