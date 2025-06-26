import 'package:budget/utils/tools.dart';
import 'package:flutter/material.dart';

class SnackbarProvider extends ChangeNotifier {
  bool _isSnackBarVisible = false;
  ScaffoldFeatureController? _currentSnackBarController;

  bool get isSnackBarVisible => _isSnackBarVisible;

  void showSnackBar(
    SnackBar snackBar, {
    void Function(dynamic)? snackbarCallback,
  }) {
    _currentSnackBarController?.close();

    _isSnackBarVisible = true;
    notifyListeners();

    final ScaffoldFeatureController thisSnackbarController =
        scaffoldMessengerKey.currentState!.showSnackBar(snackBar);

    _currentSnackBarController = thisSnackbarController;

    _currentSnackBarController!.closed.then((reason) {
      if (_currentSnackBarController == thisSnackbarController) {
        // Ensure the snackbar controller is still this one. If it isn't, we
        // don't want to do anything because there's a different callback
        // working with the snackbar.
        if (snackbarCallback != null) snackbarCallback(reason);

        _isSnackBarVisible = false;
        _currentSnackBarController = null;
        notifyListeners();
      }
    });
  }

  void hideCurrentSnackBar() => _currentSnackBarController?.close();
}
