/*
  I have all of these in a separate file because I thought I was going to 
  end up using them in multiple places. It turns out, I wasn't. At least
  not for now. At least it's good organization, right?
*/

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
