import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/settings.dart';
import '../state/app_state.dart';
import 'chip_menu.dart';
import 'config_view_page.dart';
import 'connection_card.dart';
import 'connection_history_page.dart';
import 'format.dart';
import 'log_page.dart';
import 'settings_page.dart';
import 'smart_connection_card.dart';
import 'theme.dart';
import 'status_card.dart';
import 'update_banner.dart';
import 'v2rayng_page.dart';
import 'voidcore_account_page.dart';
import 'cf_accounts_page.dart';
import '../services/voidcore_auth.dart';

enum _AppSection { voidCore, v2rayNg }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // VOIDCORE is intentionally the default section on every app launch.
  _AppSection _section = _AppSection.voidCore;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(children: [
                  Image.asset('assets/icons/ic_stat_vpn.png', width: 30, height: 30, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  Text('VOIDCORE VPN', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text('WORKSPACES', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1.1)),
              ),
              _WorkspaceButton(
                title: 'VOIDCORE',
                subtitle: state.cfAccounts.isNotEmpty ? 'Workers, Pages, WARP & MASQUE' : 'Verify Cloudflare token to unlock',
                icon: Symbols.shield_rounded,
                selected: _section == _AppSection.voidCore,
                onTap: () {
                  Navigator.pop(context);
                  if (state.cfAccounts.isEmpty) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CfAccountsPage()));
                  } else {
                    setState(() => _section = _AppSection.voidCore);
                  }
                },
              ),
              _WorkspaceButton(
                title: 'V2RayNG',
                subtitle: 'Independent profile manager',
                icon: Symbols.hub_rounded,
                selected: _section == _AppSection.v2rayNg,
                onTap: () { setState(() => _section = _AppSection.v2rayNg); Navigator.pop(context); },
              ),
              const Spacer(),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: VoidcoreAuthService().currentUser(),
                  builder: (context, snapshot) {
                    final user = snapshot.data;
                    final metadata = user?['user_metadata'];
                    final username = metadata is Map
                        ? (metadata['username'] ?? 'VOIDCORE User').toString()
                        : 'VOIDCORE Account';
                    final email = (user?['email'] ?? 'Tap to sign in').toString();
                    final verified = user?['email_confirmed_at'] != null;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VoidcoreAccountPage()))
                            .then((_) { if (mounted) setState(() {}); });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFF251642),
                              child: const Icon(Symbols.person_rounded, size: 31, color: Color(0xFFC49AFF)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(username, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                                if (user != null) ...[
                                  const SizedBox(height: 6),
                                  Text(verified ? 'VERIFIED ACCOUNT' : 'EMAIL NOT VERIFIED',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                                      color: verified ? Colors.green : scheme.tertiary)),
                                ],
                                const SizedBox(height: 4),
                                Text(state.cfAccounts.isNotEmpty ? 'CLOUDFLARE VERIFIED' : 'CLOUDFLARE NOT VERIFIED',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                    letterSpacing: .35,
                                    color: state.cfAccounts.isNotEmpty ? Colors.green : scheme.tertiary)),
                              ],
                            )),
                            Icon(Symbols.chevron_right_rounded, color: scheme.onSurfaceVariant),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: Builder(builder: (context) => IconButton(
          tooltip: 'Open navigation menu',
          icon: const Icon(Symbols.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
        )),
        centerTitle: _section == _AppSection.v2rayNg,
        title: Text(_section == _AppSection.voidCore ? 'VOIDCORE' : 'V2RayNG', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: _section == _AppSection.voidCore ? [
          ChipMenu(values: AppMode.values, selected: state.device.appMode, label: (v) => v == AppMode.proxy ? 'Proxy mode' : 'VPN mode', onSelected: state.setAppMode, enabled: !state.isBusy),
          const SizedBox(width: 4),
          IconButton(tooltip: 'Connection history', icon: const Icon(Symbols.history_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectionHistoryPage()))),
          IconButton(tooltip: 'Logs', icon: const Icon(Symbols.bug_report_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogPage()))),
          IconButton(tooltip: 'View config', icon: const Icon(Symbols.data_object_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfigViewPage()))),
          IconButton(tooltip: 'Settings', icon: const Icon(Symbols.settings_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage()))),
        ] : [
          IconButton(tooltip: 'Connection history', icon: const Icon(Symbols.history_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectionHistoryPage()))),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _section == _AppSection.v2rayNg
            ? const V2rayNgPage(key: ValueKey('workspace-v2ray'))
            : SafeArea(
                key: const ValueKey('workspace-voidcore'),
                bottom: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom + 16),
                  child: Column(children: [
                    const UpdateBanner(),
                    if (state.needsReconnect) const _ReconnectBanner(),
                    const SizedBox(height: 16),
                    const ConnectionCard(),
                    const SizedBox(height: 12),
                    const SmartConnectionCard(),
                    const SizedBox(height: 16),
                    const StatusCard(),
                    const SizedBox(height: 16),
                    const _TrafficRow(),
                    const SizedBox(height: 16),
                    if (state.worker != null && state.mode.needsWorker) const _UsageCard(),
                  ]),
                ),
              ),
      ),
    );
  }
}

class _WorkspaceButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _WorkspaceButton({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = selected
        ? scheme.primary
        : theme.brightness == Brightness.dark
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerLow;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: foreground.withValues(alpha: .78))),
              ])),
              if (selected) Icon(Symbols.check_circle_rounded, color: foreground, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      shape: roundedShape(
        kCardRadius,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
          width: 0.75,
        ),
      ),
      color: Theme.of(context).colorScheme.surfaceContainer,
      elevation: 0,
      child: ListTile(
        leading: Icon(
          Symbols.sync_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Settings changed'),
        subtitle: const Text('Reconnect to apply them.'),
        trailing: FilledButton.tonal(
          onPressed: state.reconnect,
          child: const Text('Apply'),
        ),
      ),
    );
  }
}

const _tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

/// Download and Upload cards (rate on top, session total below).
/// Always laid out so the connect button doesn't jump when the VPN connects.
class _TrafficRow extends StatelessWidget {
  const _TrafficRow();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final voidCoreOwnsTunnel = state.activeV2rayId == null && !state.v2rayConnecting && !state.v2rayDisconnecting && !state.v2raySmartConnecting;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TrafficCard(
                  icon: Symbols.arrow_downward_rounded,
                  rate: state.downSpeed,
                  total: state.totalDown,
                  enabled: voidCoreOwnsTunnel,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _TrafficCard(
                  icon: Symbols.arrow_upward_rounded,
                  rate: state.upSpeed,
                  total: state.totalUp,
                  enabled: voidCoreOwnsTunnel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  final IconData icon;
  final int rate;
  final int total;
  final bool enabled;
  const _TrafficCard({
    required this.icon,
    required this.rate,
    required this.total,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: roundedShape(
        kCardRadius,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
          width: 0.75,
        ),
      ),
      color: theme.colorScheme.surfaceContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, weight: 600, color: muted),
                const SizedBox(width: 6),
                Text(
                  enabled ? '${formatBytes(rate)}/s' : '—',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)
                      .merge(_tabular),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 2),
            Text(
              enabled ? 'Total ${formatBytes(total)}' : 'Total —',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: muted)
                  .merge(_tabular),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with a title, a refresh button and a body, used by My IP and Usage.
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool loading;
  final VoidCallback onRefresh;
  final List<Widget> children;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.loading,
    required this.onRefresh,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: roundedShape(
        kCardRadius,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
          width: 0.75,
        ),
      ),
      color: theme.colorScheme.surfaceContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                IconButton(
                  tooltip: 'Refresh',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 24,
                  ),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.refresh_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
            // Padding(
            //   padding: const EdgeInsets.only(right: 0),
            // ),
          ],
        ),
      ),
    );
  }
}

/// Label on the left, [value] right-aligned.
class _KeyValue extends StatelessWidget {
  final String label;
  final Widget value;
  const _KeyValue(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(alignment: AlignmentDirectional.centerEnd, child: value),
        ),
      ],
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard();

  /// Workers free plan daily request limit (shared by the whole account).
  static const _limit = 100000;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final usage = state.usage;
    final style = theme.textTheme.bodyMedium?.merge(_tabular);
    return _InfoCard(
      icon: Symbols.data_usage_rounded,
      title: 'Requests · last 24h',
      loading: state.loadingUsage,
      onRefresh: state.refreshUsage,
      children: [
        if (usage != null) ...[
          _KeyValue(
            'This worker',
            Text(
              formatCount(usage.worker),
              style: style?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          _AccountUsage(total: usage.total, limit: _limit),
        ] else if (state.usageError == null)
          Text(
            state.loadingUsage ? 'Loading…' : '—',
            style: theme.textTheme.bodyMedium,
          ),
        if (state.usageError != null)
          Padding(
            padding: EdgeInsets.only(top: usage != null ? 8 : 0),
            child: Text(
              state.usageError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// "12,345 · 12.3%" with a bar against the daily limit.
class _AccountUsage extends StatelessWidget {
  final int total;
  final int limit;
  const _AccountUsage({required this.total, required this.limit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total / limit;
    final style = theme.textTheme.bodyMedium?.merge(_tabular);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KeyValue(
          'Account total',
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${(ratio * 100).toStringAsFixed(1)}% · '),
                TextSpan(
                  text: formatCount(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            style: style,
          ),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: ratio >= 0.9 ? theme.colorScheme.error : null,
        ),
      ],
    );
  }
}
