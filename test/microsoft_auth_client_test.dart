import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/minecraft_launcher/logic/microsoft_auth_client.dart';

void main() {
  test('Microsoft sign-in does not borrow another launcher client ID', () {
    final client = MicrosoftAuthClient();

    expect(client.clientId, isNot('c36a9fb6-4f2a-41ff-90bd-ae7cc92031eb'));
    expect(client.clientId, MicrosoftAuthClient.defaultClientId);
  });

  test('an explicit client ID still overrides the built-in registration', () {
    final client = MicrosoftAuthClient(' custom-client-id ');

    expect(client.clientId, 'custom-client-id');
  });
}
