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

  /// Creates the user and asks Supabase Auth to send its email OTP.
  Future<void> signUp({required String username, required String email, required String password}) async {
    await _post('/auth/v1/signup', {
      'email': email.trim(),
      'password': password,
      'data': {'username': username.trim()},
    });
  }

  /// Confirms the six-digit email code from the Supabase email template.
  Future<void> verifySignupCode({required String email, required String code}) async {
    final session = await _post('/auth/v1/verify', {
      'email': email.trim(),
      'token': code.trim(),
      'type': 'signup',
    });
    if (session['access_token'] is String) {
      await _save(session);
      return;
    }
    throw Exception('Email verified, but no session was returned. Please sign in.');
  }

  Future<void> verifyEmailLink(Uri uri) async {
    final tokenHash = uri.queryParameters['token_hash'];
    final type = uri.queryParameters['type'] ?? 'signup';
    if (tokenHash == null || tokenHash.isEmpty) {
      throw Exception('Verification link is incomplete. Request a new email link.');
    }
    final session = await _post('/auth/v1/verify', {'token_hash': tokenHash, 'type': type});
    if (session['access_token'] is String) {
      await _save(session);
    } else {
      throw Exception('Email verification succeeded. Please sign in to continue.');
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    late final Map<String, dynamic> d;
    try {
      d = await _post('/auth/v1/token?grant_type=password', {
        'email': email.trim(),
        'password': password,
      });
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('banned') ||
          message.contains('suspended') ||
          message.contains('user is banned') ||
          message.contains('user_banned')) {
        throw Exception(
          'Your account is currently suspended. Access to VOIDCORE has been temporarily restricted by an administrator. If you believe this is a mistake, please contact VOIDCORE Support.',
        );
      }
      rethrow;
    }
    final user = d['user'];
    if (user is Map && user['email_confirmed_at'] == null) {
      throw Exception('Email is not verified. Verify your address, then sign in again.');
    }
    await _save(d);
  }

  Future<void> resendVerification(String email) async =>
      _post('/auth/v1/resend', {'type': 'signup', 'email': email.trim()});

  Future<Map<String, dynamic>> updateUser(Map<String, dynamic> changes, {String? redirectTo}) async {
    final token = await _storage.read(key: _access);
    if (token == null) throw Exception('Sign in to edit your account.');
    final uri = Uri.parse('$_base/auth/v1/user').replace(queryParameters: redirectTo == null ? null : {'redirect_to': redirectTo});
    final r = await http.put(uri,
      headers: {'apikey': _key, 'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(changes));
    final d = _map(r.body);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception((d['msg'] ?? d['message'] ?? d['error_description'] ?? d['error'] ?? 'Could not update account').toString());
    }
    return d;
  }

  Future<void> updateUsername(String username) async {
    await updateUser({'data': {'username': username.trim()}});
  }

  Future<void> updateEmail(String email) async {
    await updateUser({'email': email.trim()}, redirectTo: redirectUrl);
  }

  Future<void> updatePassword(String password) async {
    await updateUser({'password': password});
  }

  /// Reads the signed-in user's own profile role; never trusts editable auth metadata.
  Future<bool> isAdmin() async {
    if (!isConfigured) return false;
    final token = await _storage.read(key: _access);
    if (token == null) return false;
    final user = await currentUser();
    final id = user?['id'];
    if (id is! String || id.isEmpty) return false;
    final uri = Uri.parse('$_base/rest/v1/profiles').replace(
      queryParameters: {'select': 'role', 'id': 'eq.$id'},
    );
    final response = await http.get(uri, headers: {
      'apikey': _key,
      'Authorization': 'Bearer $token',
    });
    if (response.statusCode != 200) return false;
    final decoded = jsonDecode(response.body);
    return decoded is List && decoded.isNotEmpty &&
        decoded.first is Map && decoded.first['role'] == 'admin';
  }

  Future<Map<String, dynamic>> adminRequest(Map<String, dynamic> body) async {
    final token = await _storage.read(key: _access);
    if (token == null) throw Exception('Sign in to continue.');
    final response = await http.post(
      Uri.parse('$_base/functions/v1/admin-users'),
      headers: {'apikey': _key, 'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _map(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception((data['error'] ?? 'Admin request failed').toString());
    }
    return data;
  }

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