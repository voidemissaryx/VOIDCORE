import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

import '../services/vpn_channel.dart';

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  late final Future<({String version, String url})?> _update = _check();

  int _versionNumber(String value) {
    final clean = value.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?').firstMatch(clean);
    if (match == null) return 0;
    return int.parse(match.group(1)!) * 1000000 +
        int.parse(match.group(2)!) * 1000 +
        int.parse(match.group(3)!);
  }

  Future<({String version, String url})?> _check() async {
    try {
      final installed = await VpnChannel.appInfo().timeout(const Duration(seconds: 8));
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/voidemissaryx/VOIDCORE/releases/latest'),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final tag = (data['tag_name'] ?? '').toString();
      final url = (data['html_url'] ?? '').toString();
      final current = installed.version.isEmpty ? '1.4.2' : installed.version;
      if (tag.isEmpty || url.isEmpty || _versionNumber(tag) <= _versionNumber(current)) return null;
      return (version: tag.replaceFirst(RegExp(r'^[vV]'), ''), url: url);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<({String version, String url})?>(
      future: _update,
      builder: (context, snapshot) {
        final update = snapshot.data;
        if (update == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, .55)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .22), blurRadius: 18, offset: const Offset(0, 7))],
              ),
              child: Row(
                children: [
                  const Icon(Symbols.system_update_rounded, color: Colors.white, size: 25),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Update Available!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('VOIDCORE ${update.version}', style: TextStyle(color: Colors.white.withValues(alpha: .86), fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    onPressed: () => VpnChannel.openUrl(update.url),
                    child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
).firstMatch(clean);
    if (match == null) return 0;
    return int.parse(match.group(1)!) * 1000000 +
        int.parse(match.group(2)!) * 1000 +
        int.parse(match.group(3)!);
  }

  Future<({String version, String url})?> _check() async {
    try {
      final installed = await VpnChannel.appInfo().timeout(const Duration(seconds: 8));
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/voidemissaryx/VOIDCORE/releases/latest'),
        headers: const {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final tag = (data['tag_name'] ?? '').toString();
      final url = (data['html_url'] ?? '').toString();
      final current = installed.version.isEmpty ? '1.4.2' : installed.version;
      if (tag.isEmpty || url.isEmpty || _versionNumber(tag) <= _versionNumber(current)) return null;
      return (version: tag.replaceFirst(RegExp(r'^[vV]'), ''), url: url);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<({String version, String url})?>(
      future: _update,
      builder: (context, snapshot) {
        final update = snapshot.data;
        if (update == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, Color.lerp(scheme.primary, scheme.tertiary, .55)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .22), blurRadius: 18, offset: const Offset(0, 7))],
              ),
              child: Row(
                children: [
                  const Icon(Symbols.system_update_rounded, color: Colors.white, size: 25),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Update Available!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('VOIDCORE ${update.version}', style: TextStyle(color: Colors.white.withValues(alpha: .86), fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    onPressed: () => VpnChannel.openUrl(update.url),
                    child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
