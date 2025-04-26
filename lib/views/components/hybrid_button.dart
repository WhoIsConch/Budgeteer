import 'package:flutter/material.dart';

enum HybridButtonType { toggle, input }

class HybridButton extends StatelessWidget {
  const HybridButton({
    super.key,
    required this.buttonType,
    required this.onTap,
    required this.icon,
    this.dynamicIconSelector,
    this.text,
    this.iconSet,
    this.dataSet,
    this.isEnabled = false,
    this.preference = 1,
  });

  final HybridButtonType buttonType;
  final bool isEnabled;
  final VoidCallback onTap;
  final Icon icon;
  final Icon Function()? dynamicIconSelector;
  final String? text;
  final List<IconData>? iconSet;
  final List<dynamic>? dataSet;
  final int preference;

  Widget _buildToggleButton(BuildContext context) {
    return IconButton.outlined(
        onPressed: onTap,
        icon: icon,
        color: isEnabled
            ? Theme.of(context).buttonTheme.colorScheme?.onPrimary
            : null,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) {
              if (isEnabled) {
                return Theme.of(context).buttonTheme.colorScheme?.primary;
              }

              return null;
            },
          ),
        ));
  }

  Widget _buildInputButton(BuildContext context) {
    if (isEnabled) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).buttonTheme.colorScheme?.secondaryContainer,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(text!,
                  style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context)
                          .buttonTheme
                          .colorScheme
                          ?.onSecondaryContainer)),
            ),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).buttonTheme.colorScheme?.primary),
                child: dynamicIconSelector?.call() ?? icon),
          ]),
        ),
      );
    }

    return IconButton.outlined(
        onPressed: () => onTap(),
        style: TextButton.styleFrom(
            shape: const CircleBorder(),
            side: BorderSide(color: Theme.of(context).dividerColor)),
        icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    if (buttonType == HybridButtonType.input) {
      return _buildInputButton(context);
    } else if (buttonType == HybridButtonType.toggle) {
      return _buildToggleButton(context);
    }
    return const Placeholder();
  }
}
