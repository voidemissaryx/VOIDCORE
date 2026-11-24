import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/app_state.dart';
import 'setup_wizard.dart';

/// Cloudflare credentials are entered and verified here, not in the setup wizard.
class CfAccountsPage extends StatefulWidget {
  final bool selectForSetup;
  const CfAccountsPage({super.key, this.selectForSetup = false});

  @override
  State<CfAccountsPage> createState() => _CfAccountsPageState();
}

class _CfAccountsPageState extends State<CfAccountsPage> {
  final _token = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  CheckedToken? _verified;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (value.isNotEmpty) setState(() => _token.text = value);
  }

  Future<void> _verify() async {
    if (_token.text.trim().isEmpty) {
      setState(() => _error = 'Enter your Cloudflare API token.');
      return;
    }
    setState(() { _busy = true; _error = null; _verified = null; });
    try {
      final checked = await AppScope.read(context).checkCfToken(_token.text.trim());
      if (!mounted) return;
      if (widget.selectForSetup) {
        Navigator.of(context).pop(checked);
      } else {
        setState(() => _verified = checked);
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final saved = state.cfAccounts.isNotEmpty ? state.cfAccounts.first : null;
    final theme = Theme.of(context);
    final checked = _verified;
    return Scaffold(
      appBar: AppBar(title: const Text('Cloudflare Verification')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(checked != null || saved != null ? Symbols.verified_user_rounded : Symbols.key_rounded,
                size: 38, color: checked != null || saved != null ? Colors.green : theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(checked != null || saved != null ? 'Cloudflare token verified' : 'Verify your Cloudflare token',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Enter one Cloudflare API token. VOIDCORE checks it before enabling Workers, Pages, WARP and MASQUE.'),
              const SizedBox(height: 18),
              TextField(
                controller: _token,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Cloudflare API token',
                  errorText: _error,
                  helperText: 'The token is checked with Cloudflare. It is never sent to the VOIDCORE account service.',
                  suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Paste', onPressed: _busy ? null : _paste, icon: const Icon(Symbols.content_paste_rounded)),
                    IconButton(tooltip: _obscure ? 'Show' : 'Hide',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Symbols.visibility_rounded : Symbols.visibility_off_rounded)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: _busy ? null : _verify,
                icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Symbols.verified_rounded),
                label: Text(_busy ? 'Verifying…' : 'Verify API token'),
              )),
              if (checked != null) ...[
                const SizedBox(height: 16),
                ListTile(contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.check_circle_rounded, color: Colors.green),
                  title: Text(checked.email),
                  subtitle: Text('${checked.accounts.length} Cloudflare account(s) available')),
                if (!widget.selectForSetup)
                  SizedBox(width: double.infinity, child: FilledButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SetupWizard(addingAccount: true, initialToken: checked)),
                    ),
                    child: const Text('Install Workers, Pages, WARP & MASQUE'),
                  )),
              ] else if (saved != null) ...[
                const SizedBox(height: 16),
                ListTile(contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.cloud_done_rounded, color: Colors.green),
                  title: Text(saved.name),
                  subtitle: Text(saved.email),
                  trailing: const Icon(Symbols.check_circle_rounded, color: Colors.green)),
              ],
            ]),
          )),
          const SizedBox(height: 12),
          Text('Only one Cloudflare token is used on this device. Replace it by verifying a new token.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
