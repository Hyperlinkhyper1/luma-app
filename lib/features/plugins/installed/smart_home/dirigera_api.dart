import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'smart_light.dart';

class HubConnection {
  const HubConnection(this.host, this.token, this.certificateFingerprint);

  final String host;
  final String token;
  final String certificateFingerprint;

  Map<String, String> toJson() => {
    'host': host,
    'token': token,
    'certificateFingerprint': certificateFingerprint,
  };

  factory HubConnection.fromJson(Map<String, dynamic> json) => HubConnection(
    json['host'] as String,
    json['token'] as String,
    json['certificateFingerprint'] as String,
  );
}

class HubPairingChallenge {
  const HubPairingChallenge(
    this.host,
    this.code,
    this.verifier,
    this.certificateFingerprint,
  );

  final String host;
  final String code;
  final String verifier;
  final String certificateFingerprint;
}

abstract class DirigeraApi {
  Future<HubPairingChallenge> beginPairing(String host);
  Future<HubConnection> completePairing(HubPairingChallenge challenge);
  Future<List<SmartLight>> listLights(HubConnection connection);
  Future<void> setAttributes(
    HubConnection connection,
    String lightId,
    Map<String, Object> attributes,
  );
}

/// DIRIGERA uses a self-signed certificate. Pairing pins that certificate and
/// all subsequent calls require the same fingerprint.
class LocalDirigeraApi implements DirigeraApi {
  static const _timeout = Duration(seconds: 10);

  @override
  Future<HubPairingChallenge> beginPairing(String host) async {
    final address = InternetAddress.tryParse(host.trim());
    if (address == null || !isPrivateIpv4(address)) {
      throw const FormatException(
        'Enter the hub’s private IPv4 address from your router.',
      );
    }
    final random = Random.secure();
    final verifier = base64UrlEncode(
      List.generate(96, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
    final challenge = base64UrlEncode(
      sha256.convert(utf8.encode(verifier)).bytes,
    ).replaceAll('=', '');
    String? fingerprint;
    final result = await _request(
      host: host.trim(),
      method: 'GET',
      path: const ['v1', 'oauth', 'authorize'],
      query: {
        'audience': 'homesmart.local',
        'response_type': 'code',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
      onCertificate: (value) => fingerprint = value,
    );
    final code = (result as Map)['code'] as String?;
    if (code == null || fingerprint == null) {
      throw const FormatException(
        'The hub did not return a pairing challenge.',
      );
    }
    return HubPairingChallenge(host.trim(), code, verifier, fingerprint!);
  }

  @override
  Future<HubConnection> completePairing(HubPairingChallenge challenge) async {
    final result = await _request(
      host: challenge.host,
      method: 'POST',
      path: const ['v1', 'oauth', 'token'],
      fingerprint: challenge.certificateFingerprint,
      form: {
        'code': challenge.code,
        'name': 'luma Smart Home',
        'grant_type': 'authorization_code',
        'code_verifier': challenge.verifier,
      },
    );
    final token = (result as Map)['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw const FormatException('The hub did not return an access token.');
    }
    return HubConnection(
      challenge.host,
      token,
      challenge.certificateFingerprint,
    );
  }

  @override
  Future<List<SmartLight>> listLights(HubConnection connection) async {
    final result = await _request(
      host: connection.host,
      method: 'GET',
      path: const ['v1', 'devices'],
      fingerprint: connection.certificateFingerprint,
      token: connection.token,
    );
    return parseDirigeraLights(result);
  }

  @override
  Future<void> setAttributes(
    HubConnection connection,
    String lightId,
    Map<String, Object> attributes,
  ) async {
    await _request(
      host: connection.host,
      method: 'PATCH',
      path: ['v1', 'devices', lightId],
      fingerprint: connection.certificateFingerprint,
      token: connection.token,
      jsonBody: [
        {'attributes': attributes},
      ],
    );
  }

  static bool isPrivateIpv4(InternetAddress address) {
    if (address.type != InternetAddressType.IPv4) return false;
    final bytes = address.rawAddress;
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }

  Future<Object?> _request({
    required String host,
    required String method,
    required List<String> path,
    String? fingerprint,
    String? token,
    Map<String, String>? query,
    Map<String, String>? form,
    Object? jsonBody,
    void Function(String)? onCertificate,
  }) async {
    if (!isPrivateIpv4(
      InternetAddress.tryParse(host) ?? InternetAddress.anyIPv6,
    )) {
      throw const FormatException(
        'The hub address must be a private IPv4 address.',
      );
    }
    final client = HttpClient(
      context: SecurityContext(withTrustedRoots: false),
    );
    client.connectionTimeout = _timeout;
    client.findProxy = (_) => 'DIRECT';
    client.badCertificateCallback = (cert, certHost, port) {
      if (certHost != host || port != 8443) return false;
      final observed = sha256.convert(cert.der).toString();
      if (fingerprint != null && fingerprint != observed) return false;
      onCertificate?.call(observed);
      return true;
    };
    try {
      final uri = Uri(
        scheme: 'https',
        host: host,
        port: 8443,
        pathSegments: path,
        queryParameters: query,
      );
      final request = await client.openUrl(method, uri).timeout(_timeout);
      request.followRedirects = false;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (form != null) {
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
        );
        request.write(Uri(queryParameters: form).query);
      } else if (jsonBody != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(jsonBody));
      }
      final response = await request.close().timeout(_timeout);
      final body = await utf8.decoder.bind(response).join().timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Hub returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }
      return body.isEmpty ? null : jsonDecode(body);
    } finally {
      client.close(force: true);
    }
  }
}

List<SmartLight> parseDirigeraLights(Object? result) {
  if (result is! List) {
    throw const FormatException('Invalid hub device list.');
  }
  return result
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .where((item) {
        final attributes = item['attributes'];
        final manufacturer = attributes is Map
            ? attributes['manufacturer']
            : null;
        return item['type'] == 'light' &&
            manufacturer is String &&
            manufacturer.toLowerCase().contains('ikea');
      })
      .map(SmartLight.fromJson)
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}
