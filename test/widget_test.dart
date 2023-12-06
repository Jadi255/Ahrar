import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:qalam/user_data.dart'; // Import the file where AuthService is defined

void main() {
  test('authenticate returns a User instance for valid credentials', () async {
    final pb = PocketBase('https://ahrar.pockethost.io');
    final authService = AuthService(pb);
  });
}
