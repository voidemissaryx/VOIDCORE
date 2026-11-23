import 'package:bpb/services/proxy_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VLESS editor fields round-trip through a share link', () {
    final original = ProxyUri(
      protocol: 'vless',
      server: 'edge.example.com',
      port: 443,
      remark: 'Reality profile',
      params: const {
        'uuid': '11111111-2222-4333-8444-555555555555',
        'encryption': 'none',
        'flow': 'xtls-rprx-vision',
        'type': 'grpc',
        'serviceName': 'gateway',
        'authority': 'front.example.com',
        'security': 'reality',
        'sni': 'www.example.com',
        'fp': 'chrome',
        'pbk': 'public-key',
        'sid': '1234abcd',
        'spx': '/',
        'alpn': 'h2,http/1.1',
      },
    );

    final restored = ProxyUri.parse(original.toShareLink());
    expect(restored.protocol, 'vless');
    expect(restored.server, original.server);
    expect(restored.port, original.port);
    expect(restored.remark, original.remark);
    for (final key in original.params.keys) {
      expect(restored[key], original[key], reason: 'Field $key should survive round-trip');
    }
  });

  test('VMess editor fields round-trip through base64 JSON', () {
    final original = ProxyUri(
      protocol: 'vmess',
      server: 'vmess.example.com',
      port: 8443,
      remark: 'VMess WS',
      params: const {
        'uuid': '11111111-2222-4333-8444-555555555555',
        'alterId': '0',
        'encryption': 'auto',
        'type': 'ws',
        'headerType': 'none',
        'host': 'cdn.example.com',
        'path': '/v2ray',
        'security': 'tls',
        'sni': 'cdn.example.com',
        'fp': 'chrome',
        'alpn': 'http/1.1',
      },
    );

    final restored = ProxyUri.parse(original.toShareLink());
    expect(restored.protocol, 'vmess');
    expect(restored.server, original.server);
    expect(restored.port, original.port);
    expect(restored.remark, original.remark);
    for (final key in original.params.keys) {
      expect(restored[key], original[key], reason: 'Field $key should survive round-trip');
    }
  });

  test('Trojan credentials and transport fields round-trip', () {
    final original = ProxyUri(
      protocol: 'trojan',
      server: 'trojan.example.com',
      port: 443,
      remark: 'Trojan gRPC',
      params: const {
        'password': 'test-secret',
        'type': 'grpc',
        'security': 'tls',
        'sni': 'trojan.example.com',
        'serviceName': 'tunnel',
        'authority': 'front.example.com',
      },
    );

    final restored = ProxyUri.parse(original.toShareLink());
    expect(restored['password'], 'test-secret');
    expect(restored['type'], 'grpc');
    expect(restored['serviceName'], 'tunnel');
    expect(restored['authority'], 'front.example.com');
  });

  test('editor refuses credentials required for a usable profile', () {
    expect(
      () => const ProxyUri(
        protocol: 'vless',
        server: 'example.com',
        port: 443,
      ).toShareLink(),
      throwsFormatException,
    );
  });
}
