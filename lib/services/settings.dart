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

  Future<void> loadSettings() async {
    final SharedPreferencesWithCache prefs =
        await SharedPreferencesWithCache.create(
          cacheOptions: SharedPreferencesWithCacheOptions(
            allowList: settings.keys.toSet(),
          ),
        );

    final logger = AppLogger().logger;

    for (var entry in settings.entries) {
      var value = prefs.get(entry.key);

      if (value == null) {
        switch (entry.value) {
          case String v:
            prefs.setString(entry.key, v);
            break;
          case bool v:
            prefs.setBool(entry.key, v);
            break;
          case Enum v:
            prefs.setInt(entry.key, v.index);
            break;
        }
        logger.i('Set setting ${entry.key} to ${entry.value}');
      } else {
        settings[entry.key] = value;
      }
    }

    logger.i('Settings loaded: $settings');
  }
}
