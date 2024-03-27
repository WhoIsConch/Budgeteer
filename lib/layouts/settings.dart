import 'package:flutter/material.dart';
import 'package:budget/tools/settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Map settings;

  @override
  void initState() {
    super.initState();

    getSettings();
  }

  void getSettings() async {
    settings = await loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    return Scaffold(
        appBar: AppBar(title: Text("Settings")),
        body: Column(
          children: children,
        ));
  }
}
