import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider() {
    _initialize();
  }

  Session? _session;
  StreamSubscription<AuthState>? _authStream;

  Session? get session => _session;

  void _initialize() {
    _session = Supabase.instance.client.auth.currentSession;

    _authStream = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedOut) {
        _session = null;
      } else if (session != null) {
        _session = session;
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authStream?.cancel();
    super.dispose();
  }
}
