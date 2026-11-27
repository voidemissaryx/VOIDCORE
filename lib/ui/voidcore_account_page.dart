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

class _VoidcoreAccountPageState extends State<VoidcoreAccountPage> with WidgetsBindingObserver {
  final _auth = VoidcoreAuthService();
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _verificationCode = TextEditingController();
  bool _creating = false, _busy = false, _hide = true, _loading = true, _forgotPassword = false;
  bool _awaitingVerification = false;
  String? _message;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await _auth.currentUser();
      if (mounted) setState(() { _user = user; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _username.dispose(); _email.dispose(); _password.dispose(); _confirm.dispose(); _verificationCode.dispose();
    super.dispose();
  }

  String _error(Object error) => error.toString().replaceFirst('Exception: ', '');

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _message = null; });
    try {
      if (_creating) {
        await _auth.signUp(username: _username.text, email: _email.text, password: _password.text);
        if (mounted) setState(() {
          _creating = false;
          _awaitingVerification = true;
          _message = 'Check your inbox for the 8-digit verification code. Also check Spam or Junk.';
        });
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
        final user = await _auth.currentUser();
        if (mounted) setState(() { _user = user; _message = 'Welcome back to VOIDCORE.'; });
      }
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final email = (_user?['email'] ?? _email.text).toString();
    if (email.isEmpty) return;
    await _run(() async {
      await _auth.resendVerification(email);
      return 'A new verification email was requested. Check Inbox and Spam/Junk.';
    });
  }

  Future<void> _verifyCode() async {
    final code = _verificationCode.text.trim();
    if (!RegExp(r'^[0-9]{8}$').hasMatch(code)) {
      setState(() => _message = 'Enter the 8-digit code from your email.');
      return;
    }
    await _run(() async {
      await _auth.verifySignupCode(email: _email.text.trim(), code: code);
      final user = await _auth.currentUser();
      if (mounted) setState(() { _user = user; _awaitingVerification = false; });
      return 'Email verified. Your VOIDCORE account is ready.';
    });
  }

  Future<void> _sendPasswordReset() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _message = 'Enter your email address first.');
      return;
    }
    await _run(() async {
      await _auth.sendPasswordReset(email);
      return 'If an account exists for this email, a password recovery message has been sent.';
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() { _busy = true; _message = null; });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } catch (e) {
      if (mounted) setState(() => _message = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editField({
    required String title,
    required String label,
    required String initial,
    required String success,
    required Future<void> Function(String) save,
    String? Function(String?)? validate,
    bool obscure = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(key: form, child: TextFormField(
          controller: controller, autofocus: true, obscureText: obscure,
          autocorrect: false, decoration: InputDecoration(labelText: label),
          validator: validate,
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(dialogContext, controller.text.trim());
          }, child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await _run(() async {
      await save(value);
      await _load();
      return success;
    });
  }

  Future<void> _editUsername(String current) => _editField(
    title: 'Change username', label: 'New username', initial: current,
    success: 'Username updated.',
    validate: (v) => RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch((v ?? '').trim()) ? null : 'Use 3–24 letters, numbers or underscores.',
    save: _auth.updateUsername,
  );

  Future<void> _editEmail(String current) => _editField(
    title: 'Change email', label: 'New email address', initial: current,
    success: 'Confirmation email sent. Your new email will be active after verification.',
    validate: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email address.',
    save: _auth.updateEmail,
  );

  Future<void> _editPassword() async {
    final password = TextEditingController();
    final confirm = TextEditingController();
    final form = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'New password'),
            validator: (v) => (v ?? '').length >= 8 ? null : 'Use at least 8 characters.'),
          const SizedBox(height: 12),
          TextFormField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (v) => v == password.text ? null : 'Passwords do not match.'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(dialogContext, password.text); }, child: const Text('Update')),
        ],
      ),
    );
    password.dispose(); confirm.dispose();
    if (value == null) return;
    await _run(() async { await _auth.updatePassword(value); return 'Password updated successfully.'; });
  }

  Future<void> _signOut() async {
    await _run(() async {
      await _auth.signOut();
      if (mounted) setState(() => _user = null);
      return 'You have been signed out.';
    });
  }

  InputDecoration _authDecoration(String label, IconData icon) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(color: Color(0xFFB9AFC5)),
    prefixIcon: Icon(icon, color: const Color(0xFFB9AFC5)),
    filled: true, fillColor: const Color(0xFF211D2B),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF51465F))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFB18AFF), width: 1.4)),
  );

  Widget _authTextField({required TextEditingController controller, required String label,
    required IconData icon, TextInputType? keyboardType, String? Function(String?)? validator}) =>
    TextFormField(controller: controller, keyboardType: keyboardType, autocorrect: false,
      style: const TextStyle(color: Colors.white), decoration: _authDecoration(label, icon), validator: validator);

  Widget _authModeButton(String label, bool selected, VoidCallback onPressed) => OutlinedButton(
    onPressed: _busy ? null : onPressed,
    style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
      backgroundColor: selected ? const Color(0xFF7650C8) : const Color(0xFF211D2B),
      side: BorderSide(color: selected ? const Color(0xFF9C7AE8) : const Color(0xFF51465F)),
      padding: const EdgeInsets.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)));

  Widget _primaryAuthButton({required String label, required bool busy, required VoidCallback onPressed}) =>
    SizedBox(width: double.infinity, height: 48,
      child: FilledButton(onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7650C8), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontWeight: FontWeight.w700))));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metadata = _user?['user_metadata'];
    final username = metadata is Map ? (metadata['username'] ?? 'VOIDCORE User').toString() : 'VOIDCORE User';
    final email = (_user?['email'] ?? '').toString();
    final verified = _user?['email_confirmed_at'] != null;

    return Scaffold(
      appBar: AppBar(title: Text(_user == null ? 'VOIDCORE Account' : 'Account Settings')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              if (!VoidcoreAuthService.isConfigured)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Account service is not configured in this build.')))
              else if (_user != null) ...[
                Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
                  const CircleAvatar(radius: 42, backgroundColor: Color(0xFF251642),
                    child: Icon(Symbols.person_rounded, size: 48, color: Color(0xFFC49AFF))),
                  const SizedBox(height: 12),
                  Text(username, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(email, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Chip(avatar: Icon(verified ? Symbols.verified_rounded : Symbols.mark_email_unread_rounded, size: 18,
                    color: verified ? Colors.green : scheme.onSurfaceVariant),
                    label: Text(verified ? 'VERIFIED ACCOUNT' : 'EMAIL VERIFICATION PENDING')),
                ]))),
                const SizedBox(height: 16),
                Card(child: Column(children: [
                  ListTile(leading: const Icon(Symbols.alternate_email_rounded), title: const Text('Username'),
                    subtitle: Text(username), trailing: const Icon(Symbols.edit_rounded),
                    onTap: _busy ? null : () => _editUsername(username)),
                  const Divider(height: 1),
                  ListTile(leading: const Icon(Symbols.mail_outline_rounded), title: const Text('Email address'),
                    subtitle: Text(email), trailing: const Icon(Symbols.edit_rounded),
                    onTap: _busy ? null : () => _editEmail(email)),
                  const Divider(height: 1),
                  ListTile(leading: const Icon(Symbols.lock_reset_rounded), title: const Text('Password'),
                    subtitle: const Text('Change your account password'), trailing: const Icon(Symbols.chevron_right_rounded),
                    onTap: _busy ? null : _editPassword),
                  if (!verified) ...[
                    const Divider(height: 1),
                    ListTile(leading: const Icon(Symbols.mark_email_unread_rounded), title: const Text('Resend verification email'),
                      onTap: _busy ? null : _resend),
                  ],
                  const Divider(height: 1),
                  ListTile(leading: const Icon(Symbols.cloud_done_rounded), title: const Text('Cloudflare Verification'),
                    subtitle: const Text('Verify one API token for VOIDCORE'), trailing: const Icon(Symbols.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CfAccountsPage()))),
                  const Divider(height: 1),
                  ListTile(leading: Icon(Symbols.logout_rounded, color: scheme.error),
                    title: Text('Sign Out', style: TextStyle(color: scheme.error)), onTap: _busy ? null : _signOut),
                ])),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111019),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF393047)),
                    boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: .10), blurRadius: 32, offset: const Offset(0, 12))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(
                        color: const Color(0xFF7650C8), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Symbols.bolt_rounded, color: Colors.white, size: 22)),
                      const SizedBox(width: 10),
                      const Text('VOIDCORE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.8, fontSize: 17)),
                    ]),
                    const SizedBox(height: 28),
                    Text(_awaitingVerification ? 'Verify your email' : _forgotPassword ? 'Reset your password' : _creating ? 'Create account' : 'Welcome back',
                      style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 7),
                    Text(_awaitingVerification ? 'Enter the 8-digit security code sent to your email.' :
                      _forgotPassword ? 'We will send you a password recovery email.' :
                      _creating ? 'Create your VOIDCORE ID to get started.' : 'Sign in with your VOIDCORE account.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.45)),
                    const SizedBox(height: 24),
                    if (_awaitingVerification) ...[
                      TextField(controller: _verificationCode, keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done, maxLength: 8,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 25, letterSpacing: 8, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(counterText: '', hintText: '••••••••',
                          hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 8),
                          filled: true, fillColor: const Color(0xFF211D2B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF51465F)))),
                      ),
                      const SizedBox(height: 16),
                      _primaryAuthButton(label: 'Verify email', busy: _busy, onPressed: _verifyCode),
                      TextButton(onPressed: _busy ? null : _resend, child: const Text('Resend code')),
                      TextButton(onPressed: _busy ? null : () => setState(() { _awaitingVerification = false; _message = null; }), child: const Text('Back')),
                    ] else ...[
                      if (!_forgotPassword) ...[
                        Row(children: [
                          Expanded(child: _authModeButton('Sign in', !_creating, () => setState(() { _creating = false; _forgotPassword = false; _message = null; }))),
                          const SizedBox(width: 8),
                          Expanded(child: _authModeButton('Sign up', _creating, () => setState(() { _creating = true; _forgotPassword = false; _message = null; }))),
                        ]),
                        const SizedBox(height: 20),
                      ] else
                        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                          onPressed: _busy ? null : () => setState(() { _forgotPassword = false; _message = null; }),
                          icon: const Icon(Icons.arrow_back), label: const Text('Back to sign in'))),
                      Form(key: _form, child: Column(children: [
                        if (_creating && !_forgotPassword) ...[
                          _authTextField(controller: _username, label: 'Username', icon: Symbols.person_outline_rounded,
                            validator: (v) => RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch((v ?? '').trim()) ? null : 'Use 3–24 letters, numbers or underscores.'),
                          const SizedBox(height: 13),
                        ],
                        _authTextField(controller: _email, label: 'Email address', icon: Symbols.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email address.'),
                        if (!_forgotPassword) ...[
                          const SizedBox(height: 13),
                          TextFormField(controller: _password, obscureText: _hide, style: const TextStyle(color: Colors.white),
                            decoration: _authDecoration('Password', Symbols.lock_outline_rounded).copyWith(
                              suffixIcon: IconButton(color: Colors.white70,
                                icon: Icon(_hide ? Symbols.visibility_rounded : Symbols.visibility_off_rounded),
                                onPressed: () => setState(() => _hide = !_hide))),
                            validator: (v) => (v ?? '').length >= 8 ? null : 'Use at least 8 characters.'),
                          if (_creating) ...[
                            const SizedBox(height: 13),
                            TextFormField(controller: _confirm, obscureText: true, style: const TextStyle(color: Colors.white),
                              decoration: _authDecoration('Confirm password', Symbols.lock_reset_rounded),
                              validator: (v) => v == _password.text ? null : 'Passwords do not match.'),
                          ],
                        ],
                      ])),
                      const SizedBox(height: 18),
                      if (_message != null && _message!.startsWith('Your account is currently suspended.'))
                        Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(color: const Color(0xFF3A2028), borderRadius: BorderRadius.circular(12)),
                          child: Text(_message!, style: const TextStyle(color: Color(0xFFFFB7C1)))),
                      if (_message != null && !_message!.startsWith('Your account is currently suspended.'))
                        Padding(padding: const EdgeInsets.only(bottom: 14),
                          child: Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD1B9FF)))),
                      _primaryAuthButton(label: _forgotPassword ? 'Send recovery email' : _creating ? 'Create account' : 'Sign in',
                        busy: _busy, onPressed: _forgotPassword ? _sendPasswordReset : _submit),
                      if (!_creating && !_forgotPassword)
                        Align(alignment: Alignment.centerRight,
                          child: TextButton(onPressed: _busy ? null : () => setState(() { _forgotPassword = true; _message = null; }),
                            child: const Text('Forgot password?'))),
                    ],
                    const SizedBox(height: 18),
                    const Divider(color: Color(0xFF393047), height: 1),
                    const SizedBox(height: 14),
                    const Text('SECURE ACCESS · VOIDCORE ID', textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8D829B), fontSize: 10, letterSpacing: 1.3, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 18),
              ],
              if (_message != null && _user != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(_message!, textAlign: TextAlign.center)),
            ]),
      ))),
    );
  }
}
