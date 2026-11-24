import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/app_state.dart';
import 'setup_wizard.dart';

/// A single Cloudflare API token is verified and used for the VOIDCORE deployment.
class CfAccountsPage extends StatelessWidget {
  const CfAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final saved = state.cfAccounts.isNotEmpty ? state.cfAccounts.first : null;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cloudflare Verification')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(saved == null ? Symbols.key_rounded : Symbols.verified_user_rounded,
                size: 38, color: saved == null ? theme.colorScheme.primary : Colors.green),
              const SizedBox(height: 16),
              Text(saved == null ? 'Connect Cloudflare' : 'Cloudflare token verified',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(saved == null
                ? 'Enter one Cloudflare API token. VOIDCORE will verify it and prepare your native connection.'
                : 'One Cloudflare credential is active on this device. You can replace it by verifying another API token.'),
              if (saved != null) ...[
                const SizedBox(height: 16),
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Symbols.cloud_done_rounded),
                  title: Text(saved.name), subtitle: Text(saved.email), trailing: const Icon(Symbols.check_circle_rounded, color: Colors.green)),
              ],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SetupWizard(addingAccount: true))),
                icon: const Icon(Symbols.verified_rounded),
                label: Text(saved == null ? 'Verify API token' : 'Replace API token'),
              )),
            ]),
          )),
          const SizedBox(height: 12),
          Text('Your API token is stored locally on this device. VOIDCORE does not upload it to the VOIDCORE account service.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
