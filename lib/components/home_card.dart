import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

class HomeCard extends StatelessWidget {
  // Include a title string and a content Widget
  const HomeCard({super.key, required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      margin: EdgeInsets.zero, // So the card takes up all the space it's given
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 24,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              content,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CardButton extends StatefulWidget {
  const CardButton(
      {super.key, required this.content, this.textSize = 16, this.callback});

  final String content;
  final double textSize;
  final VoidCallback? callback;

  @override
  State<CardButton> createState() => _CardButtonState();
}

class _CardButtonState extends State<CardButton> {
  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return TextButton(
      onPressed: widget.callback,
      style: TextButton.styleFrom(
        backgroundColor: theme.buttonTheme.colorScheme?.primary,
        foregroundColor: theme.buttonTheme.colorScheme?.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: AutoSizeText(
        widget.content,
        style: TextStyle(
            fontSize: widget.textSize,
            color: theme.buttonTheme.colorScheme?.onPrimary),
        textAlign: TextAlign.center,
        minFontSize: 12,
        maxLines: 2,
      ),
    );
  }
}
