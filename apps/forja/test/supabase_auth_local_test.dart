import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _runLocal = bool.fromEnvironment('RUN_LOCAL_SUPABASE_TESTS');
const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

void main() {
  test(
    'local account signs in and can read its profiles',
    () async {
      final client = SupabaseClient(
        _url,
        _anonKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);

      final response = await client.auth.signInWithPassword(
        email: 'user@forja.local',
        password: 'password123',
      );
      expect(response.session, isNotNull);

      final rows = await client
          .from('profiles')
          .select('id, name, avatar_key')
          .order('created_at');
      expect(rows, isNotEmpty);

      await client.auth.signOut();
    },
    skip: !_runLocal || _url.isEmpty || _anonKey.isEmpty,
  );
}
