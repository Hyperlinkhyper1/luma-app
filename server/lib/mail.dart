import 'dart:convert';
import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// SMTP configuration, read from environment variables (see .env.example).
/// If [host] is empty, mail sending is disabled and callers should log
/// instead (useful for local development without a real mail server). Used
/// only for family/chat invite email now — account verification goes
/// through [ResendConfig] instead (see [Mailer.sendVerificationCode]).
class MailConfig {
  MailConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fromAddress,
    required this.fromName,
    required this.useSsl,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String fromAddress;
  final String fromName;
  final bool useSsl;

  bool get enabled => host.isNotEmpty;

  factory MailConfig.fromEnvironment(Map<String, String> env) {
    int intOf(String key, int fallback) =>
        int.tryParse(env[key] ?? '') ?? fallback;
    return MailConfig(
      host: env['LUMA_SMTP_HOST'] ?? '',
      port: intOf('LUMA_SMTP_PORT', 587),
      username: env['LUMA_SMTP_USER'] ?? '',
      password: env['LUMA_SMTP_PASS'] ?? '',
      fromAddress: env['LUMA_SMTP_FROM'] ?? '',
      fromName: env['LUMA_SMTP_FROM_NAME'] ?? 'Luma',
      useSsl: (env['LUMA_SMTP_SSL'] ?? 'false').toLowerCase() == 'true',
    );
  }
}

/// Resend (https://resend.com) configuration for the account-verification
/// email only. If [apiKey] is empty, sending is disabled and the code is
/// logged to stderr instead — useful for local testing, same fallback as
/// [MailConfig].
class ResendConfig {
  ResendConfig({
    required this.apiKey,
    required this.fromAddress,
    required this.fromName,
  });

  final String apiKey;
  final String fromAddress;
  final String fromName;

  bool get enabled => apiKey.isNotEmpty;

  factory ResendConfig.fromEnvironment(Map<String, String> env) =>
      ResendConfig(
        apiKey: env['LUMA_RESEND_API_KEY'] ?? '',
        fromAddress: env['LUMA_RESEND_FROM'] ?? 'noreply@sync.example.com',
        fromName: env['LUMA_RESEND_FROM_NAME'] ?? 'Luma',
      );
}

/// Sends account-related email: verification codes via the Resend HTTP API
/// ([sendVerificationCode]), family and chat invites via SMTP (the rest of
/// this class). Falls back to logging to stderr when the relevant config
/// isn't enabled, so local dev works with neither configured.
class Mailer {
  Mailer(this.config, {ResendConfig? resendConfig})
      : resendConfig = resendConfig ?? ResendConfig.fromEnvironment(const {});

  final MailConfig config;
  final ResendConfig resendConfig;

  /// Sends the 6-digit code a new account types back into the app to prove
  /// it owns [toEmail]. Callers should treat a thrown [StateError] the same
  /// way as an SMTP send failure — best-effort, since the user can always
  /// ask for a fresh code.
  Future<void> sendVerificationCode({
    required String toEmail,
    required String code,
  }) async {
    if (!resendConfig.enabled) {
      stderr.writeln(
          '[luma] Resend not configured; verification code for $toEmail: $code');
      return;
    }

    final client = HttpClient();
    try {
      final request =
          await client.postUrl(Uri.parse('https://api.resend.com/emails'));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${resendConfig.apiKey}')
        ..contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({
        'from': '${resendConfig.fromName} <${resendConfig.fromAddress}>',
        'to': [toEmail],
        'subject': 'Your Luma verification code',
        'text': 'Your Luma verification code is $code\n\n'
            'It expires in 10 minutes. If you did not try to create a Luma '
            'account, you can ignore this email.',
        'html': '<p>Your Luma verification code is:</p>'
            '<p style="font-size:28px;font-weight:700;letter-spacing:6px">'
            '$code</p>'
            '<p>It expires in 10 minutes. If you did not try to create a '
            'Luma account, you can ignore this email.</p>',
      })));
      final response = await request.close();
      if (response.statusCode >= 300) {
        final body = await response.transform(utf8.decoder).join();
        throw StateError(
            'Resend API returned ${response.statusCode}: $body');
      }
      await response.drain<void>();
    } finally {
      client.close();
    }
  }

  /// Notifies an invitee that they've been invited to a family. Acceptance
  /// happens in-app (via the inbox), not through a link in this email — it's
  /// just a heads-up to open Luma.
  Future<void> sendFamilyInviteEmail({
    required String toEmail,
    required String inviterEmail,
    required String familyName,
  }) async {
    if (!config.enabled) {
      stderr.writeln('[luma] SMTP not configured; family invite for '
          '$toEmail: $inviterEmail invited you to join "$familyName"');
      return;
    }

    final smtp = SmtpServer(
      config.host,
      port: config.port,
      username: config.username.isEmpty ? null : config.username,
      password: config.password.isEmpty ? null : config.password,
      ssl: config.useSsl,
    );

    final message = Message()
      ..from = Address(config.fromAddress, config.fromName)
      ..recipients.add(toEmail)
      // Defense in depth: never let CR/LF from a user-supplied name reach an
      // SMTP header, even if upstream validation is bypassed.
      ..subject =
          'You\'ve been invited to join "${_headerSafe(familyName)}" on Luma'
      ..text = '$inviterEmail invited you to join their family, '
          '"$familyName", on Luma.\n\n'
          'Open the Luma app and check the inbox icon (top-right) to accept '
          'or decline.\n\n'
          'If you don\'t use Luma or weren\'t expecting this, you can ignore '
          'this email.'
      ..html = '<p><b>${_htmlEscapeMail(inviterEmail)}</b> invited you to join '
          'their family, "${_htmlEscapeMail(familyName)}", on Luma.</p>'
          '<p>Open the Luma app and check the inbox icon (top-right) to '
          'accept or decline.</p>'
          '<p>If you don\'t use Luma or weren\'t expecting this, you can '
          'ignore this email.</p>';

    try {
      await send(message, smtp);
    } on MailerException catch (e) {
      stderr.writeln('[luma] failed to send family invite email to '
          '$toEmail: $e');
      rethrow;
    }
  }
  /// Notifies an invitee that someone wants to start an end-to-end encrypted
  /// chat with them. Like [sendFamilyInviteEmail], acceptance happens in-app
  /// (the plugin polls its own invites endpoint) — this is just a heads-up.
  Future<void> sendChatInviteEmail({
    required String toEmail,
    required String inviterEmail,
  }) async {
    if (!config.enabled) {
      stderr.writeln('[luma] SMTP not configured; chat invite for '
          '$toEmail: $inviterEmail wants to chat with you');
      return;
    }

    final smtp = SmtpServer(
      config.host,
      port: config.port,
      username: config.username.isEmpty ? null : config.username,
      password: config.password.isEmpty ? null : config.password,
      ssl: config.useSsl,
    );

    final message = Message()
      ..from = Address(config.fromAddress, config.fromName)
      ..recipients.add(toEmail)
      ..subject = '$inviterEmail wants to chat with you on Luma'
      ..text = '$inviterEmail invited you to start an end-to-end encrypted '
          'chat on Luma.\n\n'
          'Open the Luma app, go to the Chat plugin, and check your invites '
          'to accept or decline.\n\n'
          'If you don\'t use Luma or weren\'t expecting this, you can ignore '
          'this email.'
      ..html = '<p><b>${_htmlEscapeMail(inviterEmail)}</b> invited you to '
          'start an end-to-end encrypted chat on Luma.</p>'
          '<p>Open the Luma app, go to the Chat plugin, and check your '
          'invites to accept or decline.</p>'
          '<p>If you don\'t use Luma or weren\'t expecting this, you can '
          'ignore this email.</p>';

    try {
      await send(message, smtp);
    } on MailerException catch (e) {
      stderr.writeln('[luma] failed to send chat invite email to '
          '$toEmail: $e');
      rethrow;
    }
  }
}

/// Strips characters that could terminate or fold an SMTP header line.
String _headerSafe(String s) =>
    s.replaceAll(RegExp(r'[\r\n\x00-\x1f\x7f]'), ' ');

String _htmlEscapeMail(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
