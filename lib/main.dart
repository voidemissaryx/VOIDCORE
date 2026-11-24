import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'state/app_state.dart';
import 'ui/home_page.dart';
import 'ui/setup_wizard.dart';
import 'ui/theme.dart';
import 'services/voidcore_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(BpbApp(state: state));
}

class BpbApp extends StatelessWidget {
  final AppState state;
  const BpbApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      // Rebuilds only when the theme colour or mode changes (picked in Settings).
      child: ListenableBuilder(
        listenable: Listenable.merge([state.themeColor, state.themeMode]),
        builder: (context, _) => MaterialApp(
          title: 'VOIDCORE',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light, state.themeColor.value),
          darkTheme: buildTheme(Brightness.dark, state.themeColor.value),
          themeMode: state.themeMode.value,
          home: const _Root(),
        ),
      ),
    );
  }
}

/// The setup wizard until a VPN worker is set up, then the home page.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  StreamSubscription<dynamic>? _authLinks;
  final Set<String> _handledLinks = {};

  @override
  void initState() {
    super.initState();
    const events = EventChannel('voidcore/auth-links');
    _authLinks = events.receiveBroadcastStream().listen((value) {
      if (value is String) _verifyLink(value);
    }, onError: (_) {});
    _readInitialLink();
  }

  Future<void> _readInitialLink() async {
    try {
      const channel = MethodChannel('voidcore/auth-link-methods');
      final value = await channel.invokeMethod<String>('getInitialAuthLink');
      if (value != null) _verifyLink(value);
    } catch (_) {}
  }

  Future<void> _verifyLink(String raw) async {
    if (!_handledLinks.add(raw)) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'voidcore' || uri.host != 'auth-callback') return;
    try {
      await VoidcoreAuthService().verifyEmailLink(uri);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('🎉 Email verified! Your VOIDCORE account is active.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Email verification failed: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _authLinks?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsSetup = AppScope.of(context).needsSetup;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: needsSetup ? const SetupWizard(key: ValueKey('setup')) : const HomePage(key: ValueKey('home')),
    );
  }
}
