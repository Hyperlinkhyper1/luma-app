import 'dart:io';

void main() async {
  try {
    await Socket.connect('192.168.2.20', 36807, timeout: const Duration(seconds: 1));
  } catch (e) {
    print('Failed to connect to 192.168.2.20:36807. Exception: $e');
  }
}
