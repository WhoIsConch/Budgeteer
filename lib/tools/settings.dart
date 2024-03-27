import 'package:shared_preferences/shared_preferences.dart';

enum SettingType {
  boolean,
  multi,
  single,
}

final Map allSettings = {
  "theme": SettingType.multi,
};

Future<Map> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();

  for (var pair in allSettings.entries) {
    allSettings.update(pair.key, (value) {
      switch (pair.value) {
        case SettingType.boolean:
          {
            return prefs.getBool(pair.key);
          }
        case SettingType.multi:
        case SettingType.single:
          {
            return prefs.getString(pair.key);
          }
      }
    });
  }

  return allSettings;
}
