import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// SMTP configuration, read from environment variables (see .env.example).
/// If [host] is empty, mail sending is disabled and callers should log
/// instead (useful for local development without a real mail server).
class MailConfig {
  MailConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fromAddress,
    required this.fromName,
    required this.useSsl,
    required this.publicUrl,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String fromAddress;
  final String fromName;
  final bool useSsl;

  /// Base URL used to build the verification link, e.g. https://sync.example.com.
  final String publicUrl;

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
      publicUrl: (env['LUMA_PUBLIC_URL'] ?? 'http://localhost:8080')
          .replaceAll(RegExp(r'/+$'), ''),
    );
  }
}

/// Sends account-related email. Falls back to logging to stderr when
/// [MailConfig.enabled] is false, so local dev works without real SMTP.
class Mailer {
  Mailer(this.config);

  final MailConfig config;

  String verificationLink(String token) =>
      '${config.publicUrl}/api/v1/auth/verify?token=$token';

  Future<void> sendVerificationEmail({
    required String toEmail,
    required String token,
  }) async {
    final link = verificationLink(token);
    if (!config.enabled) {
      stderr.writeln('[luma] SMTP not configured; verification link for '
          '$toEmail: $link');
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
      ..subject = 'Verify your Luma account'
      ..text = 'Welcome to Luma!\n\n'
          'Please verify your email address by opening this link:\n$link\n\n'
          'This link expires in 24 hours. If you did not create a Luma '
          'account, you can ignore this email.'
      ..html = '<p>Welcome to Luma!</p>'
          '<p>Please verify your email address by clicking the link below:</p>'
          '<p><a href="$link">$link</a></p>'
          '<p>This link expires in 24 hours. If you did not create a Luma '
          'account, you can ignore this email.</p>';

    try {
      await send(message, smtp);
    } on MailerException catch (e) {
      stderr.writeln('[luma] failed to send verification email to '
          '$toEmail: $e');
      rethrow;
    }
  }
}
