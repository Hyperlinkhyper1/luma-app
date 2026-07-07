import 'dart:io';

void main() async {
  try {
    await Socket.connect('127.0.0.1', 36807, timeout: const Duration(seconds: 1));
  } catch (e) {
    print('Failed to connect. port variable: 36807, e: $e');
  }
}
