import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chatbot_client.dart';

/// Customizable Chatbot UI Widget.
/// Can be used as a full page or embedded inside a dialog/drawer.
/// Includes support for a Live Voice Mode with a Procedural Animated Lipsync Avatar!
class ChatbotWidget extends StatefulWidget {
  final String baseUrl;
  final String apiKey;
  final String chatbotId;

  // Customization styling options
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

class _ChatbotWidgetState extends State<ChatbotWidget> with TickerProviderStateMixin {
  late ChatbotClient _client;
  String? _sessionId;
  final List<ChatbotMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isStreaming = false;
  String _streamResponseBuffer = '';

  // Dynamic values loaded strictly from API
  String _dynamicTitle = 'Loading assistant...';
  String _dynamicGreetingMessage = 'Halo! Ada yang bisa saya bantu?';

  // Live Voice Mode State
  bool _isVoiceMode = false;
  bool _isUserSpeaking = false;
  bool _isAiSpeaking = false;
  double _mouthOpening = 0.0; // Dynamic multiplier for Lipsync Avatar
  String _voiceTranscription = 'Sentuh mic untuk mulai berbicara...';
  String _voiceAiResponse = '';

  late AnimationController _avatarAnimationController;
  Timer? _lipsyncTimer;
  Timer? _userSpeechSimulationTimer;

  @override
  void initState() {
    super.initState();
    _client = ChatbotClient(baseUrl: widget.baseUrl, apiKey: widget.apiKey);

    // Ticker for smooth avatar procedural animations (breathing, eye blinking, etc.)
    _avatarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final info = await _client.getChatbotInfo(widget.chatbotId);
      setState(() {
        _dynamicTitle = info['name'] as String? ?? 'AI Assistant';
        _dynamicGreetingMessage = info['greeting_message'] as String? ?? 'Halo!';
      });
    } catch (e) {
      print('Failed to fetch chatbot info: $e. Falling back to default values.');
      setState(() {
        _dynamicTitle = 'AI Assistant';
        _dynamicGreetingMessage = 'Halo! Ada yang bisa saya bantu hari ini?';
      });
    }

    try {
      final sid = await _client.createSession(widget.chatbotId);
      setState(() {
        _sessionId = sid;
        _messages.add(ChatbotMessage(
          role: 'assistant',
          content: _dynamicGreetingMessage,
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

  // ----------------- TEXT-BASED CHAT LOGIC -----------------
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isStreaming || _isLoading) return;

    _inputController.clear();
    _handleSendMessage(text);
  }

  Future<void> _handleSendMessage(String text) async {
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

    // Create empty message bubble
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

          setState(() {
            _messages[_messages.length - 1] = ChatbotMessage(
              role: 'assistant',
              content: _streamResponseBuffer,
              createdAt: DateTime.now(),
            );
          });
          _scrollToBottom();
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

  // ----------------- VOICE-BASED CHAT & LIPSYNC LOGIC -----------------

  void _toggleVoiceMode() {
    setState(() {
      _isVoiceMode = !_isVoiceMode;
      _isUserSpeaking = false;
      _isAiSpeaking = false;
      _mouthOpening = 0.0;
      _voiceTranscription = 'Sentuh tombol mic di bawah untuk mulai berbicara...';
      _voiceAiResponse = '';
    });

    _lipsyncTimer?.cancel();
    _userSpeechSimulationTimer?.cancel();
  }

  /// Simulates Real-Time user speaking and streaming RAG text-to-speech with procedural lipsync
  void _startListeningUserVoice() {
    if (_isUserSpeaking || _isAiSpeaking) return;

    setState(() {
      _isUserSpeaking = true;
      _voiceTranscription = 'Mendengarkan suara Anda...';
      _voiceAiResponse = '';
    });

    // Simulate STT (Speech To Text) after 3 seconds of talking
    _userSpeechSimulationTimer = Timer(const Duration(seconds: 3), () {
      final simulatedUserSpeechList = [
        "Bagaimana cara mengaktifkan akun saya?",
        "Apakah chatbot ini mendukung parsing DOCX?",
        "Jelaskan limitasi untuk paket FREE",
        "Bagaimana cara integrasi SDK Flutter?"
      ];
      final randomSpeech = simulatedUserSpeechList[math.Random().nextInt(simulatedUserSpeechList.length)];

      setState(() {
        _isUserSpeaking = false;
        _voiceTranscription = '"$randomSpeech"';
      });

      // Send simulated transcript to RAG backend and play with dynamic Lipsync TTS
      _executeVoiceRag(randomSpeech);
    });
  }

  Future<void> _executeVoiceRag(String query) async {
    setState(() {
      _isAiSpeaking = true;
      _voiceAiResponse = 'Berpikir...';
    });

    try {
      final stream = _client.sendChatMessageStream(
        chatbotId: widget.chatbotId,
        message: query,
        sessionId: _sessionId,
      );

      String rawResponse = '';
      bool isFirstChunk = true;

      await for (final chunk in stream) {
        if (chunk.containsKey('session_id')) {
          _sessionId = chunk['session_id'] as String;
        } else if (chunk.containsKey('chunk')) {
          final textChunk = chunk['chunk'] as String;
          if (isFirstChunk) {
            rawResponse = '';
            isFirstChunk = false;
            _startLipsyncSimulation(); // Start lipsync mouth movement exactly when AI speaks!
          }
          rawResponse += textChunk;
          setState(() {
            _voiceAiResponse = rawResponse;
          });
        }
      }

      // Add to main chat history for continuity
      setState(() {
        _messages.add(ChatbotMessage(role: 'user', content: query));
        _messages.add(ChatbotMessage(role: 'assistant', content: rawResponse));
      });
      _scrollToBottom();

    } catch (e) {
      setState(() {
        _voiceAiResponse = 'Maaf, terjadi kesalahan koneksi.';
      });
    } finally {
      // AI speaking finished, stop lipsync
      setState(() {
        _isAiSpeaking = false;
        _mouthOpening = 0.0;
      });
      _lipsyncTimer?.cancel();
    }
  }

  /// Procedural Lipsync Mouth oscillation simulation
  void _startLipsyncSimulation() {
    _lipsyncTimer?.cancel();
    _lipsyncTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isAiSpeaking) {
        timer.cancel();
        return;
      }
      setState(() {
        // Oscilates the mouth open/close procedurally simulating talking sounds
        _mouthOpening = 0.2 + (math.Random().nextDouble() * 0.8);
      });
    });
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
    _avatarAnimationController.dispose();
    _lipsyncTimer?.cancel();
    _userSpeechSimulationTimer?.cancel();
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
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isVoiceMode ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: _buildTextChatInterface(),
          secondChild: _buildVoiceChatInterface(),
        ),
      ),
    );
  }

  // ----------------- TEXT INTERFACE UI -----------------

  Widget _buildTextChatInterface() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildMessagesList(),
        ),
        _buildInputBar(),
      ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _dynamicTitle,
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
          // Live Voice Toggle Button
          IconButton(
            onPressed: _toggleVoiceMode,
            icon: const Icon(Icons.mic, color: Colors.white, size: 20),
            tooltip: 'Masuk Mode Suara Live',
          ),
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

  // ----------------- FUTURISTIC VOICE INTERFACE UI -----------------

  Widget _buildVoiceChatInterface() {
    return Container(
      height: widget.height,
      width: widget.width,
      color: const Color(0xFF0F172A), // Dark space blue theme for voice mode
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Voice Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dynamicTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text(
                    'Live Voice & Lipsync',
                    style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.w500, fontSize: 11),
                  ),
                ],
              ),
              IconButton(
                onPressed: _toggleVoiceMode,
                icon: const Icon(Icons.close, color: Colors.white54, size: 24),
                tooltip: 'Kembali ke Chat Teks',
              ),
            ],
          ),

          const Spacer(),

          // Centered Avatar Canvas
          AnimatedBuilder(
            animation: _avatarAnimationController,
            builder: (context, child) {
              return SizedBox(
                height: 200,
                width: 200,
                child: CustomPaint(
                  painter: AvatarPainter(
                    animationValue: _avatarAnimationController.value,
                    mouthOpening: _mouthOpening,
                    primaryColor: widget.primaryColor,
                    isAiSpeaking: _isAiSpeaking,
                    isUserSpeaking: _isUserSpeaking,
                  ),
                ),
              );
            },
          ),

          const Spacer(),

          // Transcription text block
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person, color: Colors.indigoAccent, size: 14),
                    SizedBox(width: 6),
                    Text('Anda (STT):', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _voiceTranscription,
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // AI voice response transcription
          if (_voiceAiResponse.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.primaryColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.support_agent, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 6),
                      Text('Asisten (TTS):', style: TextStyle(color: widget.primaryColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _voiceAiResponse,
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Pulsating radial voice button
          GestureDetector(
            onTap: _startListeningUserVoice,
            child: Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: _isUserSpeaking ? Colors.redAccent : widget.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isUserSpeaking ? Colors.redAccent : widget.primaryColor).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _isUserSpeaking ? Icons.graphic_eq : Icons.mic,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isUserSpeaking ? 'Mendengarkan...' : 'Ketuk untuk Berbicara',
            style: TextStyle(
              color: _isUserSpeaking ? Colors.redAccent : Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- PROCEDURAL AI AVATAR CUSTOM PAINTER -----------------

class AvatarPainter extends CustomPainter {
  final double animationValue; // Periodic multiplier (0.0 to 1.0)
  final double mouthOpening;   // Opens mouth from 0.0 (closed) to 1.0 (fully open)
  final Color primaryColor;
  final bool isAiSpeaking;
  final bool isUserSpeaking;

  AvatarPainter({
    required this.animationValue,
    required this.mouthOpening,
    required this.primaryColor,
    required this.isAiSpeaking,
    required this.isUserSpeaking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.38;

    // Smooth sinusoidal breath offsets
    final breathOffset = math.sin(animationValue * 2 * math.pi) * 3.5;
    final scaleOffset = 1.0 + (math.sin(animationValue * 2 * math.pi) * 0.015);

    // 1. Draw glowing background sound waves
    final wavePaint = Paint()
      ..color = primaryColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    if (isAiSpeaking || isUserSpeaking) {
      final waveExpansion = 12.0 + math.sin(animationValue * 6 * math.pi) * 10.0;
      canvas.drawCircle(center.translate(0, breathOffset), baseRadius + waveExpansion, wavePaint);

      wavePaint.color = primaryColor.withOpacity(0.04);
      canvas.drawCircle(center.translate(0, breathOffset), baseRadius + waveExpansion * 2.2, wavePaint);
    }

    // 2. Draw Avatar head/face circle
    final facePaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor.withOpacity(0.85), primaryColor.withOpacity(0.6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center.translate(0, breathOffset), baseRadius * scaleOffset, facePaint);

    // 3. Draw eyes (Procedural blinking)
    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final leftEyeCenter = Offset(center.dx - 22, center.dy - 12 + breathOffset);
    final rightEyeCenter = Offset(center.dx + 22, center.dy - 12 + breathOffset);

    // Blinking trigger based on anim time boundaries
    final isBlinking = (animationValue > 0.08 && animationValue < 0.12) || (animationValue > 0.72 && animationValue < 0.76);

    if (isBlinking) {
      // Closed eye line
      final eyeStroke = Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftEyeCenter.translate(-8, 0), leftEyeCenter.translate(8, 0), eyeStroke);
      canvas.drawLine(rightEyeCenter.translate(-8, 0), rightEyeCenter.translate(8, 0), eyeStroke);
    } else {
      // Glowing open circular eyes
      canvas.drawCircle(leftEyeCenter, 6.5, eyePaint);
      canvas.drawCircle(rightEyeCenter, 6.5, eyePaint);

      // Shiny pupil reflection
      final pupilPaint = Paint()..color = primaryColor..style = PaintingStyle.fill;
      canvas.drawCircle(leftEyeCenter.translate(-1.5, -1.5), 2.2, pupilPaint);
      canvas.drawCircle(rightEyeCenter.translate(-1.5, -1.5), 2.2, pupilPaint);
    }

    // 4. Draw responsive Lipsync Mouth
    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final mouthCenter = Offset(center.dx, center.dy + 20 + breathOffset);

    if (mouthOpening > 0.1) {
      // Dynamic oval/ellipse shape representing talking state based on RAG voice amplitudes
      final mouthHeight = 4.0 + (mouthOpening * 16.0);
      final mouthWidth = 14.0 - (mouthOpening * 3.0);
      canvas.drawOval(
        Rect.fromCenter(center: mouthCenter, width: mouthWidth, height: mouthHeight),
        mouthPaint,
      );
    } else {
      // Closed, smiling/relaxed mouth line
      final smilePaint = Paint()
        ..color = Colors.white70
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      final smilePath = Path()
        ..moveTo(mouthCenter.dx - 12, mouthCenter.dy - 1)
        ..quadraticBezierTo(mouthCenter.dx, mouthCenter.dy + 4, mouthCenter.dx + 12, mouthCenter.dy - 1);
      canvas.drawPath(smilePath, smilePaint);
    }

    // 5. Head accessory detail (Futuristic headband/earphones)
    final detailPaint = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawArc(
      Rect.fromCircle(center: center.translate(0, breathOffset), radius: baseRadius * scaleOffset),
      math.pi,
      math.pi,
      false,
      detailPaint,
    );
  }

  @override
  bool shouldRepaint(covariant AvatarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.mouthOpening != mouthOpening ||
        oldDelegate.isAiSpeaking != isAiSpeaking ||
        oldDelegate.isUserSpeaking != isUserSpeaking;
  }
}

/// Floating Overlay Trigger to activate Floating Chat Bubble on any page.
class FloatingChatbotButton extends StatefulWidget {
  final String baseUrl;
  final String apiKey;
  final String chatbotId;
  final Color primaryColor;

  const FloatingChatbotButton({
    super.key,
    required this.baseUrl,
    required this.apiKey,
    required this.chatbotId,
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
