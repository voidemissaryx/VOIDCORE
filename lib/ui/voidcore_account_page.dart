import 'package:flutter/material.dart';
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
  bool _creating = true, _busy = false, _hide = true, _loading = true;
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
    _username.dispose(); _email.dispose(); _password.dispose(); _confirm.dispose();
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
          _message = '✦ Your VOIDCORE ID is almost ready. Verify your email using the secure link we sent.';
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
      return 'A fresh verification link has been sent. Check your inbox.';
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
                const SizedBox(height: 18),
                const CircleAvatar(radius: 42, backgroundColor: Color(0xFF251642),
                  child: Icon(Symbols.person_rounded, size: 48, color: Color(0xFFC49AFF))),
                const SizedBox(height: 16),
                Text('YOUR VOIDCORE ID', textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text('One account. Your VOIDCORE experience.', textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                SegmentedButton<bool>(segments: const [
                  ButtonSegment(value: true, label: Text('Create account'), icon: Icon(Symbols.person_add_rounded)),
                  ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Symbols.login_rounded)),
                ], selected: {_creating}, onSelectionChanged: _busy ? null : (v) => setState(() { _creating = v.first; _message = null; })),
                const SizedBox(height: 20),
                Form(key: _form, child: Column(children: [
                  if (_creating) ...[
                    TextFormField(controller: _username, textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Symbols.alternate_email_rounded)),
                      validator: (v) => RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch((v ?? '').trim()) ? null : 'Use 3–24 letters, numbers or underscores.'),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Symbols.mail_outline_rounded)),
                    validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email address.'),
                  const SizedBox(height: 12),
                  TextFormField(controller: _password, obscureText: _hide,
                    decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Symbols.lock_outline_rounded),
                      suffixIcon: IconButton(icon: Icon(_hide ? Symbols.visibility_rounded : Symbols.visibility_off_rounded),
                        onPressed: () => setState(() => _hide = !_hide)),
                    ), validator: (v) => (v ?? '').length >= 8 ? null : 'Use at least 8 characters.'),
                  if (_creating) ...[
                    const SizedBox(height: 12),
                    TextFormField(controller: _confirm, obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Symbols.lock_reset_rounded)),
                      validator: (v) => v == _password.text ? null : 'Passwords do not match.'),
                  ],
                ])),
                const SizedBox(height: 16),
                if (_message != null && _message!.startsWith('Your account is currently suspended.'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Card(
                      color: scheme.errorContainer.withValues(alpha: .38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: scheme.error.withValues(alpha: .45)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Icon(Symbols.gpp_bad_rounded, size: 42, color: scheme.error),
                            const SizedBox(height: 10),
                            Text('ACCOUNT SUSPENDED',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.error, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                            const SizedBox(height: 8),
                            Text(_message!, textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                            const SizedBox(height: 10),
                            Text('VOIDCORE SECURITY · ACCESS RESTRICTED',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant, letterSpacing: .6)),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_message != null)
                  Padding(padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_message!, textAlign: TextAlign.center, style: TextStyle(color: scheme.primary))),
                FilledButton(onPressed: _busy ? null : _submit,
                  child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_creating ? 'Create VOIDCORE account' : 'Sign in')),
                if (!_creating) TextButton(onPressed: _busy ? null : _resend, child: const Text('Resend verification email')),
              ],
              if (_message != null && _user != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(_message!, textAlign: TextAlign.center)),
            ]),
      )))),
    );
  }
}
