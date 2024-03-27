
import 'package:shared_preferences/shared_preferences.dart';

enum SettingType {
  boolean,
  multi,
  button,
}

class Setting {
  final String name;
  final SettingType type;
  List<dynamic> options;
  dynamic value;

  Setting(this.name, this.type, this.options);
}

final List<Setting> allSettings = [
  Setting("Theme", SettingType.multi, ["System", "Dark", "Light"]),
  Setting("Starting Weekday", SettingType.multi, ["Sunday", "Monday"]),
  Setting("Account", SettingType.button, ["Manage"])
];

Future<List<Setting>> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();

  for (var setting in allSettings) {
    if (setting.type == SettingType.button) {
      continue;
    }

    var value = prefs.get(setting.name);

    if (setting.value == null || setting.value!.isEmpty) {
      switch (setting.type) {
        case SettingType.boolean:
          {
            await prefs.setBool(setting.name, setting.options.first);
          }

        default:
          {
            await prefs.setString(setting.name, setting.options.first);
          }
      }

      setting.value = setting.options.first;
    } else {
      setting.value = value.toString();
    }
  }

  return allSettings;
}
