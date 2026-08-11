import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Class representing a message in the chat history.
class ChatbotMessage {
  final String role;
  final String content;
  final DateTime? createdAt;

  ChatbotMessage({
    required this.role,
    required this.content,
    this.createdAt,
  });

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) {
    return ChatbotMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// Core API Client for SaaS AI Chatbot backend.
class ChatbotClient {
  final String baseUrl;
  final String apiKey;

  ChatbotClient({
    required this.baseUrl,
    required this.apiKey,
  });

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  /// Fetches basic information about the chatbot.
  Future<Map<String, dynamic>> getChatbotInfo(String chatbotId) async {
    final uri = Uri.parse('$baseUrl/api/v1/chatbots/info?chatbot_id=$chatbotId');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load chatbot info: ${response.body}');
    }
  }

  /// Creates a new chat session on the backend.
  Future<String> createSession(String chatbotId) async {
    final uri = Uri.parse('$baseUrl/api/v1/sessions');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'chatbot_id': chatbotId}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['session_id'] as String;
    } else {
      throw Exception('Failed to create session: ${response.body}');
    }
  }

  /// Fetches all chat messages for a specific session.
  Future<List<ChatbotMessage>> getSessionMessages(String sessionId) async {
    final uri = Uri.parse('$baseUrl/api/v1/sessions/$sessionId/messages');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
      return list.map((item) => ChatbotMessage.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch messages: ${response.body}');
    }
  }

  /// Sends a message and streams the assistant response using Server-Sent Events (SSE).
  /// Yields a stream of partial chunks as they arrive.
  /// First yielded string may contain the updated sessionId.
  Stream<Map<String, dynamic>> sendChatMessageStream({
    required String chatbotId,
    required String message,
    String? sessionId,
  }) async* {
    final uri = Uri.parse('$baseUrl/api/v1/chatbots/$chatbotId/chat');

    final request = http.Request('POST', uri);
    request.headers.addAll(_headers());
    request.body = jsonEncode({
      'message': message,
      if (sessionId != null) 'session_id': sessionId,
    });

    try {
      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        yield {
          'error': 'Failed to initiate chat stream (Status: ${response.statusCode})',
        };
        client.close();
        return;
      }

      // Convert byte stream to line stream
      final lineStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        if (line.startsWith('data: ')) {
          final dataString = line.substring(6).trim();
          if (dataString == '[DONE]') {
            break;
          }
          try {
            final parsed = jsonDecode(dataString) as Map<String, dynamic>;
            yield parsed; // Can contain 'session_id' or 'chunk'
          } catch (_) {
            // Ignore format issues or intermediate empty keep-alives
          }
        }
      }
      client.close();
    } catch (e) {
      yield {
        'error': 'Connection error: ${e.toString()}',
      };
    }
  }
}
