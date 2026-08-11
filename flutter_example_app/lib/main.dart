import 'package:flutter/material.dart';
import 'package:flutter_chatbot_sdk/flutter_chatbot_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SaaS AI Chatbot Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: const DemoHomeScreen(),
    );
  }
}

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({super.key});

  @override
  State<DemoHomeScreen> createState() => _DemoHomeScreenState();
}

class _DemoHomeScreenState extends State<DemoHomeScreen> {
  // Default values pointing to our backend server
  final TextEditingController _serverUrlController = TextEditingController(text: 'http://localhost:8000');
  final TextEditingController _apiKeyController = TextEditingController(text: 'Paste_Your_Public_SDK_Key_Here');
  final TextEditingController _chatbotIdController = TextEditingController(text: 'Paste_Your_Chatbot_Id_Here');
  final TextEditingController _titleController = TextEditingController(text: 'Asisten Layanan Pelanggan');
  final TextEditingController _greetingController = TextEditingController(text: 'Halo! Ada yang bisa saya bantu terkait produk atau layanan kami?');

  Color _selectedPrimaryColor = const Color(0xFF4F46E5);
  bool _useFloatingBubble = false;
  bool _isConfigured = false;

  final List<Map<String, dynamic>> _themeColors = [
    {'name': 'Indigo (Default)', 'color': const Color(0xFF4F46E5)},
    {'name': 'Emerald Green', 'color': const Color(0xFF10B981)},
    {'name': 'Teal', 'color': const Color(0xFF14B8A6)},
    {'name': 'Crimson Red', 'color': const Color(0xFFE11D48)},
    {'name': 'Violet Purple', 'color': const Color(0xFF8B5CF6)},
  ];

  void _applyConfiguration() {
    if (_apiKeyController.text.trim().isEmpty || _chatbotIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Harap masukkan Public SDK API Key dan Chatbot ID terlebih dahulu!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    setState(() {
      _isConfigured = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Konfigurasi SDK Chatbot AI berhasil diterapkan!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'SaaS AI Chatbot - Client Integration',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[200],
            height: 1.0,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIntroHeader(),
                const SizedBox(height: 24),

                // Form Configuration card
                _buildConfigurationCard(),
                const SizedBox(height: 24),

                if (_isConfigured && !_useFloatingBubble) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Live Embedded Chatbot Demo:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                    ),
                  ),
                  Center(
                    child: ChatbotWidget(
                      baseUrl: _serverUrlController.text.trim(),
                      apiKey: _apiKeyController.text.trim(),
                      chatbotId: _chatbotIdController.text.trim(),
                      title: _titleController.text.trim(),
                      greetingMessage: _greetingController.text.trim(),
                      primaryColor: _selectedPrimaryColor,
                      accentColor: _selectedPrimaryColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 60),
                ] else if (_isConfigured && _useFloatingBubble) ...[
                  Center(
                    child: Card(
                      color: Colors.green.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.green.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'Floating Chat Bubble Active!',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Silakan klik tombol chat mengambang (floating button) di pojok kanan bawah layar untuk berinteraksi.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ],
            ),
          ),

          // Render floating bubble only if configuration is applied and floating bubble option is true
          if (_isConfigured && _useFloatingBubble)
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingChatbotButton(
                baseUrl: _serverUrlController.text.trim(),
                apiKey: _apiKeyController.text.trim(),
                chatbotId: _chatbotIdController.text.trim(),
                title: _titleController.text.trim(),
                greetingMessage: _greetingController.text.trim(),
                primaryColor: _selectedPrimaryColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIntroHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: Color(0xFF4F46E5), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Integrasikan Chatbot AI pada Aplikasi Anda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4F46E5)),
                ),
                SizedBox(height: 4),
                Text(
                  'Aplikasi contoh ini menyimulasikan bagaimana developer lain mengintegrasikan Flutter SDK kami ke aplikasi mereka hanya dalam beberapa baris kode.',
                  style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard() {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Konfigurasi SDK Chatbot',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),

            // Backend Server URL
            const Text('SaaS Server URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                hintText: 'http://localhost:8000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Public SDK Key & Chatbot ID Grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Public SDK Key', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _apiKeyController,
                        decoration: InputDecoration(
                          hintText: 'sk_saas_...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chatbot ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _chatbotIdController,
                        decoration: InputDecoration(
                          hintText: 'id-chatbot-uuid',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // UI Customization Options
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Judul Bot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pilih Tema Warna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Color>(
                            value: _selectedPrimaryColor,
                            isExpanded: true,
                            onChanged: (Color? newColor) {
                              if (newColor != null) {
                                setState(() {
                                  _selectedPrimaryColor = newColor;
                                });
                              }
                            },
                            items: _themeColors.map((theme) {
                              return DropdownMenuItem<Color>(
                                value: theme['color'] as Color,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(color: theme['color'] as Color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      theme['name'] as String,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Greeting message
            const Text('Pesan Selamat Datang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _greetingController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),

            // Embed or Floating selector
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Embed di Halaman', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: false,
                    groupValue: _useFloatingBubble,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _useFloatingBubble = val!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Floating Bubble', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: true,
                    groupValue: _useFloatingBubble,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _useFloatingBubble = val!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _applyConfiguration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Terapkan & Hubungkan SDK',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
