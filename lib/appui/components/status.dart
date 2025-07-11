import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class ErrorInset extends StatelessWidget {
  final String text;
  final bool alignCenter;

  const ErrorInset(this.text, {super.key, this.alignCenter = true});

  static const noTransactions = ErrorInset('No transactions');
  static const noData = ErrorInset('No data');

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Symbols.warning_rounded,
          grade: 200,
          fill: 1,
          size: 48,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall!.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
          ),
        ),
      ],
    );

    if (!alignCenter) return content;

    return Align(alignment: Alignment.center, child: content);
  }
}
