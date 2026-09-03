import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class MicrosoftAuthException implements Exception {
  MicrosoftAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DeviceCodeInfo {
  DeviceCodeInfo({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;
}

/// The final result of a successful sign-in: everything
/// [MinecraftLauncherRepository.addOrUpdateMicrosoftAccount] needs, plus the
/// MSA refresh token (kept separately so it can be exchanged again later
/// without repeating the device-code flow).
class MicrosoftAuthResult {
  MicrosoftAuthResult({
    required this.mcAccessToken,
    required this.mcAccessTokenExpiresAt,
    required this.msaRefreshToken,
    required this.uuid,
    required this.username,
  });
  final String mcAccessToken;
  final DateTime mcAccessTokenExpiresAt;
  final String msaRefreshToken;
  final String uuid;
  final String username;
}

/// Implements the Minecraft launcher's standard "Microsoft device code +
/// Xbox Live + XSTS" sign-in chain. Requires the user to have created their
/// own Azure AD (Entra ID) public-client app registration (see
/// `LauncherSettingsStore.getMicrosoftClientId`) — Mojang's own client IDs
/// aren't reusable by third-party launchers.
class MicrosoftAuthClient {
  MicrosoftAuthClient(this.clientId);
  final String clientId;

  static const _scope = 'XboxLive.signin offline_access';

  Future<DeviceCodeInfo> requestDeviceCode() async {
    final res = await http.post(
      Uri.parse('https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode'),
      body: {'client_id': clientId, 'scope': _scope},
    );
    final json = _decode(res);
    return DeviceCodeInfo(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      expiresIn: json['expires_in'] as int,
      interval: json['interval'] as int? ?? 5,
    );
  }

  /// Polls the token endpoint until the user finishes authenticating in
  /// their browser, then completes the Xbox Live → XSTS → Minecraft services
  /// exchange chain. Throws [MicrosoftAuthException] on timeout or denial.
  Future<MicrosoftAuthResult> pollAndSignIn(DeviceCodeInfo device) async {
    final msa = await _pollForMsaToken(device);
    return _exchangeForMinecraft(msaAccessToken: msa.$1, msaRefreshToken: msa.$2);
  }

  Future<MicrosoftAuthResult> signInWithRefreshToken(String refreshToken) async {
    final res = await http.post(
      Uri.parse('https://login.microsoftonline.com/consumers/oauth2/v2.0/token'),
      body: {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'scope': _scope,
      },
    );
    final json = _decode(res);
    return _exchangeForMinecraft(
      msaAccessToken: json['access_token'] as String,
      msaRefreshToken: json['refresh_token'] as String? ?? refreshToken,
    );
  }

  Future<(String, String)> _pollForMsaToken(DeviceCodeInfo device) async {
    final deadline = DateTime.now().add(Duration(seconds: device.expiresIn));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(Duration(seconds: device.interval));
      final res = await http.post(
        Uri.parse('https://login.microsoftonline.com/consumers/oauth2/v2.0/token'),
        body: {
          'client_id': clientId,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          'device_code': device.deviceCode,
        },
      );
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final error = json['error'] as String?;
      if (error == null) {
        return (json['access_token'] as String, json['refresh_token'] as String);
      }
      if (error == 'authorization_pending') continue;
      if (error == 'authorization_declined') {
        throw MicrosoftAuthException('Sign-in was declined.');
      }
      if (error == 'expired_token') {
        throw MicrosoftAuthException('The sign-in code expired. Try again.');
      }
      throw MicrosoftAuthException(json['error_description'] as String? ?? error);
    }
    throw MicrosoftAuthException('Timed out waiting for sign-in.');
  }

  Future<MicrosoftAuthResult> _exchangeForMinecraft({
    required String msaAccessToken,
    required String msaRefreshToken,
  }) async {
    // 1. Xbox Live user token.
    final xblRes = await http.post(
      Uri.parse('https://user.auth.xboxlive.com/user/authenticate'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'Properties': {
          'AuthMethod': 'RPS',
          'SiteName': 'user.auth.xboxlive.com',
          'RpsTicket': 'd=$msaAccessToken',
        },
        'RelyingParty': 'http://auth.xboxlive.com',
        'TokenType': 'JWT',
      }),
    );
    final xbl = _decode(xblRes);
    final xblToken = xbl['Token'] as String;
    final uhs = ((xbl['DisplayClaims'] as Map)['xui'] as List).first['uhs'] as String;

    // 2. XSTS token, scoped to Minecraft services.
    final xstsRes = await http.post(
      Uri.parse('https://xsts.auth.xboxlive.com/xsts/authorize'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'Properties': {
          'SandboxId': 'RETAIL',
          'UserTokens': [xblToken],
        },
        'RelyingParty': 'rp://api.minecraftservices.com/',
        'TokenType': 'JWT',
      }),
    );
    if (xstsRes.statusCode == 401) {
      final body = jsonDecode(xstsRes.body) as Map<String, dynamic>;
      final code = body['XErr'] as int?;
      if (code == 2148916233) {
        throw MicrosoftAuthException(
            'This Microsoft account has no Xbox profile. Create one at xbox.com and try again.');
      }
      if (code == 2148916238) {
        throw MicrosoftAuthException(
            'This account is under 18 and needs a family group to sign in to Xbox services.');
      }
      throw MicrosoftAuthException('Xbox sign-in was rejected.');
    }
    final xsts = _decode(xstsRes);
    final xstsToken = xsts['Token'] as String;

    // 3. Minecraft services access token.
    final mcRes = await http.post(
      Uri.parse('https://api.minecraftservices.com/authentication/login_with_xbox'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identityToken': 'XBL3.0 x=$uhs;$xstsToken'}),
    );
    final mc = _decode(mcRes);
    final mcAccessToken = mc['access_token'] as String;
    final expiresIn = mc['expires_in'] as int? ?? 86400;

    // 4. Profile lookup for the real username/uuid.
    final profileRes = await http.get(
      Uri.parse('https://api.minecraftservices.com/minecraft/profile'),
      headers: {'Authorization': 'Bearer $mcAccessToken'},
    );
    if (profileRes.statusCode == 404) {
      throw MicrosoftAuthException('This Microsoft account does not own Minecraft.');
    }
    final profile = _decode(profileRes);

    return MicrosoftAuthResult(
      mcAccessToken: mcAccessToken,
      mcAccessTokenExpiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      msaRefreshToken: msaRefreshToken,
      uuid: profile['id'] as String,
      username: profile['name'] as String,
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw MicrosoftAuthException('Unexpected response (${res.statusCode}).');
    }
    if (res.statusCode >= 400) {
      throw MicrosoftAuthException(
          json['error_description'] as String? ?? json['Message'] as String? ?? 'Request failed (${res.statusCode}).');
    }
    return json;
  }
}
