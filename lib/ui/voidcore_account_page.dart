import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/voidcore_auth.dart';

class VoidcoreAccountPage extends StatefulWidget {
  const VoidcoreAccountPage({super.key});
  @override
  State<VoidcoreAccountPage> createState() => _VoidcoreAccountPageState();
}
class _VoidcoreAccountPageState extends State<VoidcoreAccountPage> {
  final _auth = VoidcoreAuthService();
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(), _email = TextEditingController();
  final _password = TextEditingController(), _confirm = TextEditingController();
  bool _creating = true, _busy = false, _hide = true;
  String? _message;
  Map<String, dynamic>? _user;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final u = await _auth.currentUser(); if (mounted) setState(() => _user = u); }
  @override
  void dispose() { _username.dispose(); _email.dispose(); _password.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _message = null; });
    try {
      if (_creating) {
        await _auth.signUp(username: _username.text, email: _email.text, password: _password.text);
        if (mounted) setState(() { _creating = false; _message = 'Account created. Verify your email, then sign in.'; });
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
        final u = await _auth.currentUser();
        if (mounted) setState(() { _user = u; _message = 'Signed in successfully.'; });
      }
    } catch (e) { if (mounted) setState(() => _message = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(appBar: AppBar(title: const Text('VOIDCORE Account')),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 16),
          CircleAvatar(radius: 42, backgroundColor: t.colorScheme.primaryContainer,
            child: Icon(Symbols.person_rounded, size: 44, color: t.colorScheme.onPrimaryContainer)),
          const SizedBox(height: 16),
          Text('VOIDCORE ACCOUNT', textAlign: TextAlign.center,
            style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const SizedBox(height: 12),
          if (!VoidcoreAuthService.isConfigured)
            const Text('Account service is not configured in this build. Check GitHub Actions variables.', textAlign: TextAlign.center)
          else if (_user != null) ...[
            Card(child: ListTile(leading: const Icon(Symbols.verified_user_rounded),
              title: Text((_user!['user_metadata']?['username'] ?? 'VOIDCORE user').toString()),
              subtitle: Text((_user!['email'] ?? '').toString()), trailing: const Icon(Symbols.verified_rounded, color: Colors.green))),
            OutlinedButton.icon(onPressed: _busy ? null : () async {
              setState(() => _busy = true); await _auth.signOut();
              if (mounted) setState(() { _user = null; _busy = false; });
            }, icon: const Icon(Symbols.logout_rounded), label: const Text('Sign out')),
          ] else ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Create account'), icon: Icon(Symbols.person_add_rounded)),
                ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Symbols.login_rounded)),
              ],
              selected: {_creating}, onSelectionChanged: _busy ? null : (v) => setState(() { _creating = v.first; _message = null; })),
            const SizedBox(height: 20),
            Form(key: _form, child: Column(children: [
              if (_creating) ...[
                TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Symbols.alternate_email_rounded)),
                  validator: (v) => !_creating || RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch((v ?? '').trim()) ? null : 'Use 3–24 letters, numbers or underscores.'),
                const SizedBox(height: 12),
              ],
              TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Symbols.mail_outline_rounded)),
                validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email address.'),
              const SizedBox(height: 12),
              TextFormField(controller: _password, obscureText: _hide,
                decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Symbols.lock_outline_rounded),
                  suffixIcon: IconButton(icon: Icon(_hide ? Symbols.visibility_rounded : Symbols.visibility_off_rounded), onPressed: () => setState(() => _hide = !_hide))),
                validator: (v) => (v ?? '').length >= 8 ? null : 'Use at least 8 characters.'),
              if (_creating) ...[
                const SizedBox(height: 12),
                TextFormField(controller: _confirm, obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Symbols.lock_reset_rounded)),
                  validator: (v) => v == _password.text ? null : 'Passwords do not match.'),
              ],
            ])),
            const SizedBox(height: 16),
            if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(_message!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.primary))),
            FilledButton(onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_creating ? 'Create VOIDCORE account' : 'Sign in')),
            if (!_creating) TextButton(onPressed: _busy ? null : () async {
              setState(() { _busy = true; _message = null; });
              try { await _auth.resendVerification(_email.text); if (mounted) setState(() => _message = 'Verification email requested.'); }
              catch (e) { if (mounted) setState(() => _message = e.toString().replaceFirst('Exception: ', '')); }
              finally { if (mounted) setState(() => _busy = false); }
            }, child: const Text('Resend verification email')),
          ],
        ]),
      ))));
  }
}
