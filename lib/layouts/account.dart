import 'package:flutter/material.dart';
import 'package:budget/layouts/settings.dart';

class Account extends StatelessWidget {
  const Account({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text("Not Signed In", style: TextStyle(fontSize: 24.0)),
            const Spacer(),
            IconButton(
              iconSize: 24.0,
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ));
              },
            ),
          ],
        ),
        const Divider(),
      ],
    );
  }
}
