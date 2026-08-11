import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chatbot_sdk/flutter_chatbot_sdk.dart';

void main() {
  group('ChatbotMessage Parsing Tests', () {
    test('Should parse ChatbotMessage correctly from JSON', () {
      final jsonMap = {
        'role': 'assistant',
        'content': 'Halo, ini adalah pesan tes!',
        'created_at': '2025-01-01T12:00:00Z',
      };

      final msg = ChatbotMessage.fromJson(jsonMap);

      expect(msg.role, 'assistant');
      expect(msg.content, 'Halo, ini adalah pesan tes!');
      expect(msg.createdAt, isNotNull);
      expect(msg.createdAt!.year, 2025);
    });
  });

  group('ChatbotClient Config Verification', () {
    test('Client stores baseUrl and apiKey securely', () {
      final client = ChatbotClient(
        baseUrl: 'http://localhost:8000',
        apiKey: 'sk_saas_testkey123',
      );

      expect(client.baseUrl, 'http://localhost:8000');
      expect(client.apiKey, 'sk_saas_testkey123');
    });
  });
}
