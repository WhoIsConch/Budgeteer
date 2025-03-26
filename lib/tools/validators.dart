/*
  I have all of these in a separate file because I thought I was going to 
  end up using them in multiple places. It turns out, I wasn't. At least
  not for now. At least it's good organization, right?
*/

import 'package:flutter/services.dart';

String? validateAmount(value) {
  if (value == null || value.isEmpty) {
    return "Please enter an amount";
  } else if (double.tryParse(value) == null) {
    return "Please enter a valid amount";
  }
  double intValue = double.parse(value);
  if (intValue > 100000000) {
    return "No way you have that much money";
  }
  if (intValue < 0) {
    return "Please enter a positive amount";
  }
  return null;
}

String? validateTitle(value) {
  if (value == null || value.isEmpty) {
    return "Please enter a title";
  } else if (value.length > 50) {
    return "Title must be less than 50 characters";
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

    final RegExp regex = RegExp(r'^\d+\.?\d{0,2}$');

    if (regex.hasMatch(text)) {
      if (oldValue.text == "0") {
        return TextEditingValue(text: newValue.text.substring(1));
      }
      return newValue;
    } else if (newValue.text.isEmpty) {
      return const TextEditingValue(text: "0");
    } else {
      return oldValue;
    }
  }
}
