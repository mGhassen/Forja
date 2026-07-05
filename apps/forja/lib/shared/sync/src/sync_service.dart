import 'package:flutter/foundation.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool get isSignedIn => _signedIn;
  bool _signedIn = false;
  String? userEmail;

  /// v1.2: wire to Supabase Auth + settings blob sync.
  Future<bool> signIn({required String email, required String password}) async {
    debugPrint('[Sync] signIn stub: $email');
    _signedIn = true;
    userEmail = email;
    return true;
  }

  Future<void> signOut() async {
    _signedIn = false;
    userEmail = null;
  }

  Future<void> pushSettings(Map<String, dynamic> domains) async {
    if (!_signedIn) return;
    debugPrint('[Sync] pushSettings stub: ${domains.keys}');
  }

  Future<Map<String, dynamic>?> pullSettings() async {
    if (!_signedIn) return null;
    return {};
  }
}
