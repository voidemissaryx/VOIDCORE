import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../services/voidcore_auth.dart';
import 'cf_accounts_page.dart';

class VoidcoreAccountPage extends StatefulWidget {
  const VoidcoreAccountPage({super.key});

  @override
  State<VoidcoreAccountPage> createState() => _VoidcoreAccountPageState();
}

class _VoidcoreAccountPageState extends State<VoidcoreAccountPage> {
  final _auth = VoidcoreAuthService();
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _creating = true, _busy = false, _hide = true;
  String? _message;
  Map<String, dynamic>? _user;
  StreamSubscription<dynamic>? _authLinkSubscription;
  final Set<String> _handledLinks = {};

  @override
  void initState() {
    super.initState();
    _load();
    _listenForVerificationLinks();
  }

  Future<void> _load() async {
    final user = await _auth.currentUser();
    if (mounted) setState(() => _user = user);
  }


  Future<void> _listenForVerificationLinks() async {
    const events = EventChannel('voidcore/auth-links');
    _authLinkSubscription = events.receiveBroadcastStream().listen((value) {
      if (value is String) _handleVerificationLink(value);
    }, onError: (_) {});
    try {
      const initial = MethodChannel('voidcore/auth-link-methods');
      final value = await initial.invokeMethod<String>('getInitialAuthLink');
      if (value != null) _handleVerificationLink(value);
    } catch (_) {}
  }

  Future<void> _handleVerificationLink(String rawLink) async {
    if (!_handledLinks.add(rawLink)) return;
    final uri = Uri.tryParse(rawLink);
    if (uri == null || uri.scheme != 'voidcore' || uri.host != 'auth-callback') return;
    if (mounted) setState(() { _busy = true; _message = 'Verifying your email securely…'; });
    try {
      await _auth.verifyEmailLink(uri);
      final user = await _auth.currentUser();
      if (mounted) setState(() {
        _user = user;
        _message = '🎉 Email verified! Your VOIDCORE account is now active.';
      });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _authLinkSubscription?.cancel();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _message = null; });
    try {
      if (_creating) {
        await _auth.signUp(
          username: _username.text,
          email: _email.text,
          password: _password.text,
        );
        if (mounted) {
          setState(() {
            _creating = false;
            _message = '✉️ Check your inbox — your VOIDCORE journey starts with one quick verification.';
            _email.text = _email.text.trim();
          });
        }
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
        final user = await _auth.currentUser();
        if (mounted) setState(() { _user = user; _message = 'Welcome back to VOIDCORE.'; });
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await _auth.signOut();
      if (mounted) setState(() { _user = null; _message = 'You have been signed out.'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() { _busy = true; _message = null; });
    try {
      await _auth.resendVerification(_email.text);
      if (mounted) setState(() => _message = '📨 A fresh verification link is on its way. Check your inbox and spam folder.');
    } catch (error) {
      if (mounted) setState(() => _message = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metadata = _user?['user_metadata'];
    final username = metadata is Map ? (metadata['username'] ?? 'VOIDCORE User').toString() : 'VOIDCORE User';
    final email = (_user?['email'] ?? '').toString();
    final verified = _user?['email_confirmed_at'] != null;

    return Scaffold(
      appBar: AppBar(title: const Text('VOIDCORE Account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (!VoidcoreAuthService.isConfigured)
                  const Card(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Account service is not configured in this build. Check the Supabase build variables.'),
                  ))
                else if (_user != null) ...[
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: const Color(0xFF251642),
                            child: const Icon(Symbols.person_rounded, size: 54, color: Color(0xFFC49AFF)),
                          ),
                          const SizedBox(height: 14),
                          Text(username, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(email, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: verified ? Colors.green.withValues(alpha: .13) : scheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(verified ? Symbols.verified_rounded : Symbols.mark_email_unread_rounded,
                                size: 17, color: verified ? Colors.green : scheme.onTertiaryContainer),
                              const SizedBox(width: 7),
                              Text(verified ? 'VERIFIED VOIDCORE ACCOUNT' : 'EMAIL VERIFICATION PENDING',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11,
                                  color: verified ? Colors.green : scheme.onTertiaryContainer)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(child: Column(children: [
                    ListTile(
                      leading: const Icon(Symbols.person_rounded),
                      title: const Text('My Account'),
                      subtitle: const Text('Account identity and sign-in details'),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => showAboutDialog(context: context, applicationName: 'VOIDCORE Account',
                        children: [Text('Username: $username\nEmail: $email')]),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Symbols.cloud_done_rounded),
                      title: const Text('Cloudflare Verification'),
                      subtitle: const Text('Manage your Cloudflare accounts and deployments'),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CfAccountsPage()),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Symbols.settings_rounded),
                      title: const Text('Account Settings'),
                      subtitle: const Text('Refresh account status'),
                      trailing: const Icon(Symbols.refresh_rounded),
                      onTap: _busy ? null : _load,
                    ),
                    if (!verified) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Symbols.mark_email_unread_rounded),
                        title: const Text('Resend verification email'),
                        subtitle: const Text('Send a new confirmation link'),
                        onTap: _busy ? null : _resend,
                      ),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Symbols.logout_rounded, color: scheme.error),
                      title: Text('Sign Out', style: TextStyle(color: scheme.error)),
                      onTap: _busy ? null : _signOut,
                    ),
                  ])),
                ] else ...[
                  const SizedBox(height: 18),
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFF251642),
                    child: const Icon(Symbols.person_rounded, size: 48, color: Color(0xFFC49AFF)),
                  ),
                  const SizedBox(height: 16),
                  Text('YOUR VOIDCORE ID', textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text('One account. Your VOIDCORE experience.', textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Create account'), icon: Icon(Symbols.person_add_rounded)),
                      ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Symbols.login_rounded)),
                    ],
                    selected: {_creating},
                    onSelectionChanged: _busy ? null : (value) => setState(() { _creating = value.first; _message = null; }),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _form,
                    child: Column(children: [
                      if (_creating) ...[
                        TextFormField(
                          controller: _username,
                          textCapitalization: TextCapitalization.none,
                          decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Symbols.alternate_email_rounded)),
                          validator: (value) => !_creating || RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch((value ?? '').trim())
                            ? null : 'Use 3–24 letters, numbers or underscores.',
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Symbols.mail_outline_rounded)),
                        validator: (value) => (value ?? '').contains('@') ? null : 'Enter a valid email address.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _hide,
                        decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Symbols.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_hide ? Symbols.visibility_rounded : Symbols.visibility_off_rounded),
                            onPressed: () => setState(() => _hide = !_hide),
                          )),
                        validator: (value) => (value ?? '').length >= 8 ? null : 'Use at least 8 characters.',
                      ),
                      if (_creating) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirm,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Symbols.lock_reset_rounded)),
                          validator: (value) => value == _password.text ? null : 'Passwords do not match.',
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),
                  if (_message != null) Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_message!, textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary)),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_creating ? 'Create VOIDCORE account' : 'Sign in'),
                  ),
                  if (!_creating) TextButton(
                    onPressed: _busy ? null : _resend,
                    child: const Text('Resend verification email'),
                  ),
                ],
                if (_message != null && _user != null)
                  Padding(padding: const EdgeInsets.only(top: 12), child: Text(_message!, textAlign: TextAlign.center)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
