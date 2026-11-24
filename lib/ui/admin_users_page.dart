import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/voidcore_auth.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _auth = VoidcoreAuthService();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _auth.adminRequest({'action': 'list'});
      final items = (data['users'] as List? ?? [])
          .whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList();
      if (mounted) setState(() { _users = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _action(Map<String, dynamic> user, String action) async {
    final username = (user['username'] ?? 'this account').toString();
    if (action == 'delete') {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: Text('This permanently deletes $username and its VOIDCORE authentication account. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete account')),
        ],
      ));
      if (ok != true) return;
    }
    try {
      await _auth.adminRequest({'action': action, 'userId': user['id']});
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'delete' ? 'Account deleted.' : action == 'disable' ? 'Account disabled.' : 'Account enabled.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _edit(Map<String, dynamic> user) async {
    final username = TextEditingController(text: (user['username'] ?? '').toString());
    final email = TextEditingController(text: (user['email'] ?? '').toString());
    final password = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit account'),
      content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: username, decoration: const InputDecoration(labelText: 'Username'),
          validator: (v) => RegExp(r'^[A-Za-z0-9_]{3,24}$').hasMatch((v ?? '').trim()) ? null : 'Use 3–24 letters, numbers or underscores.'),
        const SizedBox(height: 12),
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email address'),
          validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email.'),
        const SizedBox(height: 12),
        TextFormField(controller: password, obscureText: true,
          decoration: const InputDecoration(labelText: 'New password (optional)'),
          validator: (v) => (v == null || v.isEmpty || v.length >= 8) ? null : 'Use at least 8 characters.'),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Save')),
      ],
    ));
    if (result != true) { username.dispose(); email.dispose(); password.dispose(); return; }
    try {
      await _auth.adminRequest({
        'action': 'update', 'userId': user['id'],
        'username': username.text.trim(), 'email': email.text.trim(),
        if (password.text.isNotEmpty) 'password': password.text,
      });
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account updated. A changed email may require confirmation.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { username.dispose(); email.dispose(); password.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('VOIDCORE Admin'),
        actions: [IconButton(tooltip: 'Refresh accounts', onPressed: _loading ? null : _load, icon: const Icon(Symbols.refresh_rounded))],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Symbols.admin_panel_settings_rounded, size: 44),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ])))
          : RefreshIndicator(onRefresh: _load, child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('USER DIRECTORY', style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text('${_users.length} accounts', style: theme.textTheme.bodySmall),
                const SizedBox(height: 14),
                for (final user in _users) _userCard(user, theme),
                if (_users.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('No accounts found.', textAlign: TextAlign.center)),
              ],
            )),
    );
  }

  Widget _userCard(Map<String, dynamic> user, ThemeData theme) {
    final isAdmin = user['role'] == 'admin';
    final disabled = user['disabled'] == true;
    final username = (user['username'] ?? 'Unknown').toString();
    final email = (user['email'] ?? 'No email').toString();
    final verified = user['email_confirmed_at'] != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(child: Icon(isAdmin ? Symbols.admin_panel_settings_rounded : Symbols.person_rounded)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(username, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
            ])),
            if (isAdmin) const Chip(label: Text('ADMIN'))
            else Chip(label: Text(disabled ? 'DISABLED' : 'ACTIVE')),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _status(verified ? 'EMAIL VERIFIED' : 'UNVERIFIED', verified ? Colors.green : Colors.orange),
            if (isAdmin) _status('PROTECTED ADMIN', theme.colorScheme.primary),
          ]),
          if (!isAdmin) ...[
            const Divider(height: 20),
            Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 4, children: [
              TextButton.icon(onPressed: () => _edit(user), icon: const Icon(Symbols.edit_rounded), label: const Text('Edit')),
              TextButton.icon(onPressed: () => _action(user, disabled ? 'enable' : 'disable'),
                icon: Icon(disabled ? Symbols.lock_open_rounded : Symbols.block_rounded),
                label: Text(disabled ? 'Enable' : 'Disable')),
              TextButton.icon(onPressed: () => _action(user, 'delete'),
                icon: const Icon(Symbols.delete_outline_rounded), label: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error)),
            ]),
          ],
        ],
      )),
    );
  }

  Widget _status(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
  );
}
