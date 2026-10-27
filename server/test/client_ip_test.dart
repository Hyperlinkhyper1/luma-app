import 'package:luma_sync_server/api.dart';
import 'package:luma_sync_server/util.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Per-IP limits, bans and the admin lockout all key on this address, so
/// it must be the real client and not something an attacker can rotate.
void main() {
  ServerConfig config({bool trustProxy = true, String? header}) =>
      ServerConfig(
        port: 0,
        dataDir: '.',
        allowRegistration: true,
        maxBlobBytes: 1,
        tokenTtl: const Duration(days: 1),
        corsOrigin: '*',
        trustProxy: trustProxy,
        verificationTtl: const Duration(minutes: 10),
        maxVerificationEmailsPerHour: 1,
        approvalMode: ApprovalMode.open,
        adminKey: null,
        mistralApiKey: null,
        googleApiKey: null,
        itadApiKey: null,
        groceriesUrl: '',
        groceriesAdminKey: null,
        artificialAnalysisKey: null,
        repoPath: null,
        wikiDir: null,
        publicUrl: 'http://localhost',
        oauthProviders: const {},
        clientIpHeader: header,
      );

  Request req(Map<String, String> headers) =>
      Request('GET', Uri.parse('http://localhost/'), headers: headers);

  test('the proxy-set header wins over X-Forwarded-For', () {
    final key = Api.clientKeyFor(
        req({
          'x-luma-client-ip': '203.0.113.7',
          'x-forwarded-for': '1.2.3.4, 162.158.1.1',
        }),
        config(header: 'x-luma-client-ip'));
    expect(key, '203.0.113.7');
  });

  test('without the header it falls back to the last forwarded hop', () {
    expect(
        Api.clientKeyFor(req({'x-forwarded-for': '1.2.3.4, 162.158.1.1'}),
            config(header: 'x-luma-client-ip')),
        '162.158.1.1');
  });

  test('headers are ignored unless the proxy is trusted', () {
    expect(
        Api.clientKeyFor(req({'x-luma-client-ip': '203.0.113.7'}),
            config(trustProxy: false, header: 'x-luma-client-ip')),
        'unknown');
  });

  test('IPv6 clients share one bucket per /64', () {
    final a = Api.clientKeyFor(
        req({'x-luma-client-ip': '2001:db8:1:2:aaaa::1'}),
        config(header: 'x-luma-client-ip'));
    final b = Api.clientKeyFor(
        req({'x-luma-client-ip': '2001:db8:1:2:ffff:ffff:ffff:ffff'}),
        config(header: 'x-luma-client-ip'));
    expect(a, '2001:db8:1:2::/64');
    expect(b, a);
  });

  test('ipBucket keeps IPv4 and unwraps IPv4-mapped addresses', () {
    expect(ipBucket('198.51.100.9'), '198.51.100.9');
    expect(ipBucket('::ffff:198.51.100.9'), '198.51.100.9');
    expect(ipBucket('[2001:db8::1]'), '2001:db8:0:0::/64');
    expect(ipBucket('2001:db8:0:0::/64'), '2001:db8:0:0::/64');
    expect(ipBucket('unknown'), 'unknown');
  });
}
