import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class VoidcoreAuthService {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _access = 'voidcore.auth.access';
  static const _refresh = 'voidcore.auth.refresh';
  static const _storage = FlutterSecureStorage();
  static const redirectUrl = 'voidcore://auth-callback';
  static bool get isConfigured => _url.startsWith('https://') && _key.isNotEmpty;
  String get _base => _url.replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, dynamic>?> currentUser() async {
    if (!isConfigured) return null;
    final token = await _storage.read(key: _access);
    if (token == null) return null;
    final r = await http.get(Uri.parse('$_base/auth/v1/user'),
      headers: {'apikey': _key, 'Authorization': 'Bearer $token'});
    if (r.statusCode == 200) return _map(r.body);
    if (r.statusCode == 401) await _clear();
    return null;
  }

  Future<void> signUp({required String username, required String email, required String password}) async {
    final d = await _post('/auth/v1/signup?redirect_to=${Uri.encodeComponent(redirectUrl)}', {'email': email.trim(), 'password': password, 'data': {'username': username.trim()}});
    if (d['access_token'] is String) await _save(d);
  }


  /// Completes Supabase email confirmation links delivered to the native app scheme.
  Future<void> verifyEmailLink(Uri uri) async {
    final tokenHash = uri.queryParameters['token_hash'];
    final type = uri.queryParameters['type'] ?? 'signup';
    if (tokenHash == null || tokenHash.isEmpty) {
      throw Exception('Verification link is incomplete. Request a new email link.');
    }
    final session = await _post('/auth/v1/verify', {
      'token_hash': tokenHash,
      'type': type,
    });
    if (session['access_token'] is String) await _save(session);
    else throw Exception('Email verification succeeded, but no sign-in session was returned. Sign in again.');
  }

  Future<void> signIn({required String email, required String password}) async {
    final d = await _post('/auth/v1/token?grant_type=password', {'email': email.trim(), 'password': password});
    final user = d['user'];
    if (user is Map && user['email_confirmed_at'] == null) {
      throw Exception('Email is not verified. Verify your address, then sign in again.');
    }
    await _save(d);
  }

  Future<void> resendVerification(String email) async =>
      _post('/auth/v1/resend', {'type': 'signup', 'email': email.trim()});

  Future<void> signOut() async {
    final token = await _storage.read(key: _access);
    try {
      if (token != null && isConfigured) {
        await http.post(Uri.parse('$_base/auth/v1/logout'), headers: {'apikey': _key, 'Authorization': 'Bearer $token'});
      }
    } finally { await _clear(); }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    if (!isConfigured) throw Exception('Supabase is not configured in this build.');
    final r = await http.post(Uri.parse('$_base$path'),
      headers: {'apikey': _key, 'Content-Type': 'application/json'}, body: jsonEncode(body));
    final d = _map(r.body);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception((d['msg'] ?? d['message'] ?? d['error_description'] ?? d['error'] ?? 'Supabase error').toString());
    }
    return d;
  }

  Future<void> _save(Map<String, dynamic> d) async {
    if (d['access_token'] is String) await _storage.write(key: _access, value: d['access_token']);
    if (d['refresh_token'] is String) await _storage.write(key: _refresh, value: d['refresh_token']);
  }
  Future<void> _clear() async { await _storage.delete(key: _access); await _storage.delete(key: _refresh); }
  static Map<String, dynamic> _map(String body) {
    try { final v = jsonDecode(body); return v is Map ? Map<String, dynamic>.from(v) : {}; }
    catch (_) { return {}; }
  }
}
