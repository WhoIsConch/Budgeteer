import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:budget/tools/api.dart';
import 'package:provider/provider.dart';

enum CardTextStyle { major, cluster }

class OverviewCard extends StatelessWidget {
  final String title;
  final String content;
  final CardTextStyle textStyle;
  final Function? onPressed;

  const OverviewCard(
      {super.key,
      required this.title,
      required this.content,
      required this.textStyle,
      this.onPressed});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    TextStyle? titleStyle = theme.textTheme.titleSmall;
    TextStyle? contentStyle = theme.textTheme.headlineLarge;

    if (textStyle == CardTextStyle.major) {
      titleStyle = const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
      contentStyle = const TextStyle(fontSize: 48);
    }

    Widget cardContent = Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(textAlign: TextAlign.center, title, style: titleStyle),
            Text(textAlign: TextAlign.center, content, style: contentStyle),
          ]),
    );

    if (onPressed != null) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        color: theme.colorScheme.primaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed as void Function()?,
          child: cardContent,
        ),
      );
    } else {
      return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          color: theme.colorScheme.primaryContainer,
          child: cardContent);
    }
  }
}

class AsyncOverviewCard extends StatelessWidget {
  final String title;
  final Future<double> Function(TransactionProvider) amountCalculator;
  final VoidCallback? onPressed;
  final String previousContent;
  final CardTextStyle textStyle;
  final Function(String)? onContentUpdated;

  const AsyncOverviewCard({
    Key? key,
    required this.title,
    required this.amountCalculator,
    this.textStyle = CardTextStyle.cluster,
    this.previousContent = "\$0.00",
    this.onPressed,
    this.onContentUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
        builder: (context, transactionProvider, child) {
      return FutureBuilder<double>(
          future: amountCalculator(transactionProvider),
          builder: (context, snapshot) {
            String displayAmount = previousContent;

            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                displayAmount = "Error";
              } else if (snapshot.hasData) {
                displayAmount = '\$${snapshot.data!.toStringAsFixed(2)}';
                onContentUpdated?.call(displayAmount);
              }
            }

            return OverviewCard(
              title: title,
              content: displayAmount,
              onPressed: onPressed,
              textStyle: textStyle,
            );
          });
    });
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
