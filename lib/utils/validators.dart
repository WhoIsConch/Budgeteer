import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AmountValidator {
  final bool allowZero;

  const AmountValidator({this.allowZero = false});

  /// Used in a TextFormField, ValidateAmount ensures only positive numbers can
  /// be input in a text field. [DecimalTextInputFormatter] is also typically
  /// used with this validator which generally makes this validator useless,
  /// but if the input formatter is bypassed, this is a reasonable failsafe.
  String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      if (!allowZero) {
        return 'Please enter an amount';
      } else {
        value = '0';
      }
    }

    double? amount = double.tryParse(value);

    if (amount == null || (amount == 0 && !allowZero)) {
      return 'Please enter a valid amount';
    }

    // Make sure the amount entered isn't too small or too high
    if (amount < 0) {
      return 'Please enter a positive amount';
    } else if (amount > 100_000_000) {
      // Enforce a hard limit because it would probably mess up the UI to put in a
      // number too big
      // If some hyper rich guy likes using my app for some reason and requests I
      // allow him to input transactions that are more than 100 million dollars
      // I might fix it
      return 'No way you have that much money';
    }
    return null;
  }
}

/// Formats a form field to ensure it contains nothing but a valid, parsable
/// number at all times.
class DecimalTextInputFormatter extends TextInputFormatter {
  // In retrospect, I probably could have just tried to parse the number
  // at all times to ensure it's valid instead of all of this regex junk.
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // The following regex ensures the number input is a string that can only
    // contain digits and a single dot. If there is a dot present, it only
    // allows up to two digits after it.
    final RegExp regex = RegExp(r'^\d+\.?\d{0,2}$');

    if (regex.hasMatch(text)) {
      // A regex match would mean the number is a valid number formatted as
      // `xxx.xx`, `xxx`, or `xxx.x`, or similar.
      if (newValue.text[0] == '0' &&
          newValue.text.length > 1 &&
          newValue.text[1] != '.') {
        return TextEditingValue(text: newValue.text.substring(1));
      }
      return newValue;
    } else if (newValue.text.isEmpty) {
      return const TextEditingValue(text: '0');
    } else {
      return oldValue;
    }
  }
}

/// Format a number to a valid string that matches the constraints of where
/// it's used. Can truncate large numbers and round decimal numbers.
///
/// [round] will round a decimal number to the nearest whole number.
/// [exact] will ensure large numbers are not abbreviated.
/// [truncateIfWhole] will truncate the decimal places on whole numbers.
///
/// [round] and [exact] can work together, in which the method will round a
/// large number to the nearest whole number but will not abbreviate it.
/// If [exact] is true, [truncateIfWhole] will have no effect.
String formatAmount(
  num amount, {
  bool round = false,
  bool exact = false,
  bool truncateIfWhole = true,
}) {
  NumberFormat formatter;

  if (round || (truncateIfWhole && amount.round() == amount && !exact)) {
    formatter = NumberFormat('#,###');
    amount = amount.round();
  } else {
    formatter = NumberFormat('#,##0.00');
  }

  if (exact) {
    // Exact doesn't truncate large numbers with letters
    // Used for showing account balance cards
    // non exact: 5000 -> 5k
    // exact: 5000 -> 5,000.00
    return formatter.format(amount);
  }

  num amountToFormat;
  String? character;

  if (amount >= 1_000_000_000) {
    amountToFormat = amount / 1_000_000_000;
    character = 'B';
  } else if (amount >= 1_000_000) {
    amountToFormat = amount / 1_000_000;
    character = 'M';
  } else if (amount >= 1000) {
    amountToFormat = amount / 1000;
    character = 'K';
  } else {
    amountToFormat = amount;
  }

  return '${formatter.format(amountToFormat)}${character ?? ""}';
}

/// A simple regex validator to ensure the email a user puts in to sign up
/// or log in is valid. This regex is borrowed from
/// https://www.regular-expressions.info/email.html
String? validateEmail(String? value) {
  final RegExp regex = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );

  if (value == null || value.isEmpty) {
    return 'Required';
  }

  if (regex.hasMatch(value)) {
    return null;
  }

  return 'Invalid email address';
}

/// Ensures the title of an object input by a user is less than the maximum
/// length, fifty characters. It also makes sure the title isn't empty,
/// perfect for a form field validator
String? validateTitle(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a title';
  } else if (value.length > 50) {
    return 'Title must be less than 50 characters';
  }
  return null;
}

/// Formats the Y axis value in the statistic page's bar chart.
String formatYValue(double value) {
  if (value.abs() >= 1_000_000) {
    // Use 'M' for millions
    return NumberFormat.compactSimpleCurrency(locale: 'en_US', decimalDigits: 1)
        .format(value)
        .replaceAll('\$', ''); // Remove currency symbol if not needed
  } else if (value.abs() >= 1000) {
    // Use 'K' for thousands
    return NumberFormat.compactSimpleCurrency(
      locale: 'en_US',
      decimalDigits: value.abs() < 10_000 ? 1 : 0,
    ) // More precision for lower thousands
    .format(value).replaceAll('\$', '');
  } else {
    // Show regular number for smaller values
    return NumberFormat.decimalPattern().format(value);
  }
}

String toTitleCase(String s) => s
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());
