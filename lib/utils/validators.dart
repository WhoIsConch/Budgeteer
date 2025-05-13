/*
  I have all of these in a separate file because I thought I was going to 
  end up using them in multiple places. It turns out, I wasn't. At least
  not for now. At least it's good organization, right?
*/

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AmountValidator {
  final bool allowZero;

  const AmountValidator({this.allowZero = false});

  String? validateAmount(String? value) {
    /*
  Used in a TextFormField, validateAmount ensures only positive numbers can be
  input in a text field. DecimalTextInputFormatter is also typically used with
  this validator which generally makes this validator useless, but if someone
  bypasses the input formatter somehow, this is a reasonable failsafe. 
  */

    if (value == null) {
      return 'Please enter an amount';
    }

    double? amount = double.tryParse(value);

    if (amount == null || (!allowZero && amount == 0)) {
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

String? validateTitle(String? value) {
  /* 
  Ensure the transaction title input by a user is less than the maximum length.
  Also makes sure the title isn't empty. 
  */
  if (value == null || value.isEmpty) {
    return 'Please enter a title';
  } else if (value.length > 50) {
    return 'Title must be less than 50 characters';
  }
  return null;
}

class DecimalTextInputFormatter extends TextInputFormatter {
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

String formatAmount(num amount, {bool round = false, bool exact = false}) {
  NumberFormat formatter;

  if (round) {
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
