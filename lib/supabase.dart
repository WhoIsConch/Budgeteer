import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_config/flutter_config.dart';

loadSupabase() async {
  await Supabase.initialize(
      url: FlutterConfig.get("SUPABASE_URL"),
      anonKey: FlutterConfig.get("SUPABASE_KEY"));
}
