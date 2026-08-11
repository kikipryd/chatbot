# SaaS AI Chatbot Platform with RAG & Flutter SDK

A powerful, highly scalable, and fully functional **SaaS AI Chatbot platform** using **OpenAI**, featuring an automatic **RAG (Retrieval-Augmented Generation)** engine that allows users to upload custom **PDF** and **DOCX** files as knowledge bases. It includes a beautiful web-based SaaS dashboard and a production-grade **Flutter SDK** that works natively on **iOS, Android, Web, and Desktop (Windows, macOS, Linux)**.

---

## 🏗️ Architecture Overview

The system is designed with scalability and high-concurrency in mind:
1.  **Backend & RAG Engine (`/backend`):** Built with **FastAPI (Python)** for modern, asynchronous web execution. Documents are automatically chunked using recursive boundary character splittings and embedded via OpenAI. Vector storage is implemented within an optimized SQLite schema using cosine-similarity arithmetic, prepared to seamlessly scale to a PostgreSQL/pgvector database.
2.  **SaaS Admin Dashboard:** Integrated into FastAPI using Tailwind CSS & Jinja2 templates. Allows tenants (subscribers) to sign up, select SaaS tiers, manage chatbots, upload DOC/PDF documents, and copy integration credentials.
3.  **Client Flutter SDK (`/flutter_chatbot_sdk`):** A modular Flutter package delivering core API clients, event-based **Server-Sent Events (SSE) streaming** for real-time typewriter effects, and a highly customizable modern chat widget (`ChatbotWidget` & `FloatingChatbotButton`).
4.  **Flutter Example App (`/flutter_example_app`):** A pre-configured cross-platform test application demonstrating how easily clients integrate our SDK with custom styles, titles, and greeting messages.

---

## ⚡ Quick Start: Backend Server

### 1. Installation & Environment Configuration
Navigate to the backend directory and install the required dependencies:
```bash
cd backend
pip install -r requirements.txt
```

If you wish to use live OpenAI features, define your API key in your terminal or env configuration:
```bash
export OPENAI_API_KEY="sk-proj-..."
```
*(If no API Key is provided or starts with `mock_`, the system automatically enters high-fidelity simulated RAG fallback mode, allowing complete local development, parsing, embedding, and testing without any OpenAI API costs!)*

### 2. Start the FastAPI Server
Run the local development server using Uvicorn:
```bash
uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```
Visit **`http://localhost:8000`** in your browser to sign up as a new Tenant, create your chatbot, upload PDF/DOCX files, and access the interactive playground!

---

## 📱 Quick Start: Flutter SDK Client Integration

### 1. Add Dependency to `pubspec.yaml`
Import the local SDK package or host it in your private Git repository:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_chatbot_sdk:
    path: ./flutter_chatbot_sdk
```

### 2. Use the Built-in `ChatbotWidget` (Embedded UI Pane)
Embed the beautiful AI Chat Assistant directly inside any page or view. **Note:** *The Title and Greeting Message are automatically and dynamically loaded from your SaaS Dashboard (Database) via the API! There is no need to hardcode them in the client app!*
```dart
import 'package:flutter/material.dart';
import 'package:flutter_chatbot_sdk/flutter_chatbot_sdk.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ChatbotWidget(
          baseUrl: 'http://localhost:8000',
          apiKey: 'YOUR_TENANT_PUBLIC_SDK_KEY',
          chatbotId: 'YOUR_CHATBOT_UUID',
          primaryColor: Colors.deepPurple,
        ),
      ),
    );
  }
}
```

### 3. Use the `FloatingChatbotButton` (Floating Chat Bubble)
Simply add a floating customer support widget with floating bubble logic:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_chatbot_sdk/flutter_chatbot_sdk.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(child: Text("Halaman Utama")),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingChatbotButton(
              baseUrl: 'http://localhost:8000',
              apiKey: 'YOUR_TENANT_PUBLIC_SDK_KEY',
              chatbotId: 'YOUR_CHATBOT_UUID',
              primaryColor: Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 🧪 Running Unit & Integration Tests

### Backend Python Tests:
```bash
python3 -m unittest backend/test_backend.py
```

### Flutter SDK Package Tests:
```bash
cd flutter_chatbot_sdk
flutter test
```

### Flutter Example Application Tests:
```bash
cd flutter_example_app
flutter test
```

---

## 💡 Key Architectural Choices for High Scalability
1.  **FastAPI Async Execution:** Handles high concurrency for message streams without blocking CPU cycles.
2.  **Server-Sent Events (SSE):** Streaming response model utilizes direct lightweight chunk transfers, creating real-time response flows without WebSocket handshake complexity or state maintenance overhead.
3.  **Deterministic Vector Mock Fallback:** High-performance, offline-safe testing vector fallback based on content hashing. Perfect for sandbox isolation and local automated unit tests.
4.  **No Platform-Specific Channels in SDK:** SDK uses pure Dart `http.Client` parsing, meaning there are no native cocoa/android dependencies, ensuring flawless multi-platform execution across Android, iOS, Web, Windows, macOS, and Linux.
