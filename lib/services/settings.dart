import 'package:budget/utils/tools.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// I realize these settings need a major rewrite

class Setting<T> {
  final String name;
  List<T> options;
  T value;

  Setting({required this.name, required this.options, required this.value});
}

class SettingsService with ChangeNotifier {
  // Before settings are loaded, the value acts as a default
  Map<String, dynamic> settings = {
    'Theme': ThemeMode.system,
    'Starting Weekday': 'Sunday',
    '_showTour': true,
  };

  late final SharedPreferencesWithCache _prefs;

  Future<void> loadSettings() async {
    _prefs = await SharedPreferencesWithCache.create(
      cacheOptions: SharedPreferencesWithCacheOptions(
        allowList: settings.keys.toSet(),
      ),
    );

    final logger = AppLogger().logger;

    for (var entry in settings.entries) {
      var value = _prefs.get(entry.key);

      if (value == null) {
        setSetting(entry.key, entry.value, notify: false);

        logger.i('Set setting ${entry.key} to ${entry.value}');
      } else {
        settings[entry.key] = value;
      }
    }

    logger.i('Settings loaded: $settings');
  }

  void setSetting(String name, dynamic value, {bool notify = true}) {
    if (!settings.containsKey(name)) {
      throw 'No such setting $name';
    }

    settings[name] = value;

    if (notify) notifyListeners();

    switch (value) {
      case String v:
        _prefs.setString(name, v);
        break;
      case bool v:
        _prefs.setBool(name, v);
        break;
      case Enum v:
        _prefs.setInt(name, v.index);
        break;
    }
  }
}
