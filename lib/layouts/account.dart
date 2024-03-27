import 'package:flutter/material.dart';
import 'package:budget/layouts/settings.dart';

class Account extends StatelessWidget {
  const Account({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.settings),
      onPressed: () {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsPage(),
            ));
      },
    );
  }
}
