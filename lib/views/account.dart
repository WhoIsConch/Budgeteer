import 'package:flutter/material.dart';

class Account extends StatelessWidget {
  const Account({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
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
          ],
        ),
        Divider(),
      ],
    );
  }
}
