import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_example_app/main.dart';

void main() {
  testWidgets('Demo App configuration screen renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that intro header exists
    expect(find.text('Integrasikan Chatbot AI pada Aplikasi Anda'), findsOneWidget);

    // Verify config title
    expect(find.text('Konfigurasi SDK Chatbot'), findsOneWidget);

    // Verify "Terapkan & Hubungkan SDK" button
    expect(find.text('Terapkan & Hubungkan SDK'), findsOneWidget);
  });
}
