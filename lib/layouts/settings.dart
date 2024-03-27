import 'package:flutter/material.dart';
import 'package:budget/tools/settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Setting> settings = [];
  final TextStyle settingTextStyle = const TextStyle(
    fontSize: 18.0,
  );

  @override
  void initState() {
    super.initState();

    getSettings();
  }

  void getSettings() async {
    List<Setting> loadedSettings = await loadSettings();
    setState(() {
      settings = loadedSettings;
    });
  }

  Widget makeBool(Setting setting) {
    print("In MakeBool");
    return Row(children: [
      Text(setting.name, style: settingTextStyle),
      const Spacer(),
      Checkbox(value: setting.value, onChanged: (bool? newVal) {})
    ]);
  }

  Widget makeMulti(Setting setting) {
    print("In MakeString");
    return Row(children: [
      Text(setting.name, style: settingTextStyle),
      const Spacer(),
      DropdownMenu(
        initialSelection: setting.value,
        dropdownMenuEntries: setting.options
            .map((e) => DropdownMenuEntry(
                  value: e,
                  label: e,
                ))
            .toList(),
      )
    ]);
  }

  Widget makeButton(Setting setting) {
    return Row(children: [
      Text(setting.name, style: settingTextStyle),
      const Spacer(),
      TextButton(child: Text(setting.options.first, style: settingTextStyle), onPressed: () {})
    ]);
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    for (var setting in settings) {
      Widget widget;

      switch (setting.type) {
        case SettingType.boolean:
          {
            widget = makeBool(setting);
          }

        case SettingType.button:
          {
            widget = makeButton(setting);
          }

        default:
          {
            widget = makeMulti(setting);
          }
      }

      children.add(Padding(
        padding: const EdgeInsets.all(8.0),
        child: widget,
      ));
    }

    return Scaffold(
        appBar: AppBar(title: const Text("Settings")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: children,
          ),
        ));
  }
}
