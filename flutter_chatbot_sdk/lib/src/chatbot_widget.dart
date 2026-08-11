import 'package:flutter/material.dart';
import 'chatbot_client.dart';

/// Customizable Chatbot UI Widget.
/// Can be used as a full page or embedded inside a dialog/drawer.
class ChatbotWidget extends StatefulWidget {
  final String baseUrl;
  final String apiKey;
  final String chatbotId;

  // Customization styling options
  final String title;
  final String greetingMessage;
  final Color primaryColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color cardColor;
  final TextStyle? titleTextStyle;
  final TextStyle? messageTextStyle;
  final double height;
  final double width;
  final bool isFloating;

  const ChatbotWidget({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.chatbotId,
    this.title = 'AI Assistant',
    this.greetingMessage = 'Halo! Ada yang bisa saya bantu hari ini?',
    this.primaryColor = const Color(0xFF4F46E5), // Indigo
    this.accentColor = const Color(0xFF6366F1), // Indigo accent
    this.backgroundColor = const Color(0xFFF8FAFC), // Slate 50
    this.cardColor = Colors.white,
    this.titleTextStyle,
    this.messageTextStyle,
    this.height = 550,
    this.width = 380,
    this.isFloating = false,
  });

  @override
  State<ChatbotWidget> createState() => _ChatbotWidgetState();
}

class _ChatbotWidgetState extends State<ChatbotWidget> {
  late ChatbotClient _client;
  String? _sessionId;
  final List<ChatbotMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isStreaming = false;
  String _streamResponseBuffer = '';

  @override
  void initState() {
    super.initState();
    _client = ChatbotClient(baseUrl: widget.baseUrl, apiKey: widget.apiKey);
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Create a session on the backend
      final sid = await _client.createSession(widget.chatbotId);
      setState(() {
        _sessionId = sid;
        // Add default welcome message
        _messages.add(ChatbotMessage(
          role: 'assistant',
          content: widget.greetingMessage,
          createdAt: DateTime.now(),
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatbotMessage(
          role: 'assistant',
          content: 'Error: Gagal terhubung ke server chatbot. Silakan periksa koneksi Anda.',
          createdAt: DateTime.now(),
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isStreaming || _isLoading) return;

    _inputController.clear();

    setState(() {
      _messages.add(ChatbotMessage(
        role: 'user',
        content: text,
        createdAt: DateTime.now(),
      ));
      _isStreaming = true;
      _streamResponseBuffer = '';
    });
    _scrollToBottom();

    // Create an empty temporary assistant response bubble for streaming
    setState(() {
      _messages.add(ChatbotMessage(
        role: 'assistant',
        content: '...',
        createdAt: DateTime.now(),
      ));
    });

    try {
      final stream = _client.sendChatMessageStream(
        chatbotId: widget.chatbotId,
        message: text,
        sessionId: _sessionId,
      );

      bool isFirstChunk = true;

      await for (final chunk in stream) {
        if (chunk.containsKey('session_id')) {
          _sessionId = chunk['session_id'] as String;
        } else if (chunk.containsKey('chunk')) {
          final textChunk = chunk['chunk'] as String;
          if (isFirstChunk) {
            _streamResponseBuffer = '';
            isFirstChunk = false;
          }
          _streamResponseBuffer += textChunk;

          // Update the last bubble
          setState(() {
            _messages[_messages.length - 1] = ChatbotMessage(
              role: 'assistant',
              content: _streamResponseBuffer,
              createdAt: DateTime.now(),
            );
          });
          _scrollToBottom();
        } else if (chunk.containsKey('error')) {
          final errorMsg = chunk['error'] as String;
          setState(() {
            _messages[_messages.length - 1] = ChatbotMessage(
              role: 'assistant',
              content: 'Error: $errorMsg',
              createdAt: DateTime.now(),
            );
          });
        }
      }
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = ChatbotMessage(
          role: 'assistant',
          content: 'Terjadi kesalahan saat memproses jawaban: ${e.toString()}',
          createdAt: DateTime.now(),
        );
      });
    } finally {
      setState(() {
        _isStreaming = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _resetChat() async {
    setState(() {
      _messages.clear();
    });
    await _initializeChat();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header Bar
            _buildHeader(),

            // Messages list area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMessagesList(),
            ),

            // Input bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.primaryColor, widget.accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Bot Logo/Avatar
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.assistant, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Title & State
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: widget.titleTextStyle ?? const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      height: 6,
                      width: 6,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'RAG AI Active',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Refresh/Reset Button
          IconButton(
            onPressed: _resetChat,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            tooltip: 'Reset Sesi Chat',
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg.role == 'user';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.support_agent, color: widget.primaryColor, size: 14),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? widget.primaryColor : widget.cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: isUser ? null : Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: _isBubbleLoading(msg)
                      ? _buildTypingIndicator()
                      : Text(
                          msg.content,
                          style: widget.messageTextStyle ?? TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 6),
              ]
            ],
          ),
        );
      },
    );
  }

  bool _isBubbleLoading(ChatbotMessage msg) {
    return msg.content == '...' && _isStreaming && _messages.indexOf(msg) == _messages.length - 1;
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 6,
          width: 6,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _inputController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Tulis pesan...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: widget.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.send, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating Overlay Trigger to activate Floating Chat Bubble on any page.
class FloatingChatbotButton extends StatefulWidget {
  final String baseUrl;
  final String apiKey;
  final String chatbotId;
  final String title;
  final String greetingMessage;
  final Color primaryColor;

  const FloatingChatbotButton({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.chatbotId,
    this.title = 'Asisten AI',
    this.greetingMessage = 'Halo! Ada yang bisa saya bantu?',
    this.primaryColor = const Color(0xFF4F46E5),
  });

  @override
  State<FloatingChatbotButton> createState() => _FloatingChatbotButtonState();
}

class _FloatingChatbotButtonState extends State<FloatingChatbotButton> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        if (_isOpen)
          Positioned(
            bottom: 80,
            right: 0,
            child: ChatbotWidget(
              baseUrl: widget.baseUrl,
              apiKey: widget.apiKey,
              chatbotId: widget.chatbotId,
              title: widget.title,
              greetingMessage: widget.greetingMessage,
              primaryColor: widget.primaryColor,
              isFloating: true,
            ),
          ),
        GestureDetector(
          onTap: () {
            setState(() {
              _isOpen = !_isOpen;
            });
          },
          child: Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: widget.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: AnimatedCrossFade(
                firstChild: const Icon(Icons.chat_bubble, color: Colors.white, size: 28),
                secondChild: const Icon(Icons.close, color: Colors.white, size: 28),
                crossFadeState: _isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
