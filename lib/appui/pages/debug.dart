import 'package:budget/appui/components/help_popup.dart';
import 'package:budget/appui/components/objects_list.dart';
import 'package:budget/appui/pages/settings.dart';
import 'package:budget/models/database_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class Account extends StatelessWidget {
  const Account({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Column(
          spacing: 16,
          children: [
            // const Text("Not Signed In", style: TextStyle(fontSize: 24.0)),
            // const Spacer(),
            // IconButton(
            //   iconSize: 24.0,
            //   icon: const Icon(Icons.settings),
            //   onPressed: () {
            //     Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //           builder: (context) => const SettingsPage(),
            //         ));
            //   },
            // ),
            // TextButton(
            //     onPressed: () async {
            //       scaffoldMessengerKey.currentState!
            //           .showSnackBar(const SnackBar(
            //         duration: Duration(days: 1),
            //         content: Text("Generating dummy data..."),
            //       ));
            //       await Provider.of<TransactionProvider>(context, listen: false)
            //           .createDummyData();
            //       scaffoldMessengerKey.currentState!.hideCurrentSnackBar();
            //       scaffoldMessengerKey.currentState!
            //           .showSnackBar(const SnackBar(
            //         duration: Duration(seconds: 3),
            //         content: Text("Generated!"),
            //       ));
            //     },
            //     child: const Text("Create Dummy Data")),

            // TextButton(
            //     onPressed: () async {
            //       await FirebaseAuth.instance.signOut();
            //     },
            //     child: Text("Log out with Firebase Auth")),

            // TextButton(
            //   onPressed: () async {
            //     var db = FirestoreDatabaseHelper();
            //     db.transactions
            //         .where('type', isEqualTo: TransactionType.expense.value)
            //         .get()
            //         .then((res) => print(res.docs.length));
            //   },
            //   child: Text("Send Firestore Data"),
            // )
            TextButton(
              onPressed: () {
                var colors = Theme.of(context).colorScheme;

                print('--- Surfaces ---');
                print(colors.surface.toHexString());
                print(colors.surfaceBright.toHexString());
                print(colors.surfaceDim.toHexString());
                print(colors.surfaceContainer.toHexString());
                print(colors.surfaceContainerLowest.toHexString());
                print(colors.surfaceContainerLow.toHexString());
                print(colors.surfaceContainerHigh.toHexString());
                print(colors.surfaceContainerHighest.toHexString());
                print('--- Primaries ---');
                print(colors.primary.toHexString());
                print(colors.primaryContainer.toHexString());
                print(colors.primaryFixed.toHexString());
                print(colors.primaryFixedDim.toHexString());
                print(colors.inversePrimary.toHexString());
              },
              child: Text('Print color information'),
            ),
            TextButton(
              child: Text('View help dialog'),
              onPressed:
                  () => showDialog(
                    context: context,
                    builder:
                        (_) => HelpPopup(
                          title: 'Help me',
                          description: 'You are being helped',
                        ),
                  ),
            ),
            TextButton(
              child: Text('Open settings'),
              onPressed:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => SettingsPage())),
            ),
            SizedBox(height: 400, child: ObjectsList<GoalTileableAdapter>()),
          ],
        ),
        Divider(),
      ],
    );
  }
}
