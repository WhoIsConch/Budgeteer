import 'package:flutter/material.dart';

class HelpPopup extends StatelessWidget {
  final AssetImage? image;
  final String title;
  final String description;

  const HelpPopup({
    super.key,
    this.image,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      actions: [
        TextButton(
          child: Text('Ok'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The image (or GIF)
          Placeholder(fallbackHeight: 150),
          Text(title),
          Text(description),
        ],
      ),
    );
  }
}
