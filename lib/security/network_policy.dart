import 'package:flutter/foundation.dart';

/// Authentication and private server data require TLS. Only debug builds
/// may use literal loopback HTTP for local development.
void requirePrivateTransport(Uri uri, {bool debugBuild = kDebugMode}) {
  final local = const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
  if (uri.userInfo.isNotEmpty ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' &&
          !(debugBuild && local && uri.scheme == 'http'))) {
    throw const FormatException('Private server connections require HTTPS.');
  }
}
