import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:phytopi_dashboard/main.dart';
import 'package:phytopi_dashboard/features/auth/providers/auth_provider.dart';

void main() {
  group('PhytoPi Dashboard Tests', () {
    testWidgets('Dashboard displays welcome message', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );

      // Verify that the welcome message is displayed
      expect(find.text('Welcome to PhytoPi Dashboard'), findsOneWidget);
      expect(find.text('Your IoT Plant Monitoring System'), findsOneWidget);
      expect(find.text('🌱 Hello World! Dashboard is ready! 🌱'), findsOneWidget);
    });

    testWidgets('Floating action button works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: MaterialApp(
            home: const DashboardScreen(),
          ),
        ),
      );

      // Find and tap the floating action button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Verify that a snackbar appears
      expect(find.text('Dashboard is working! 🎉'), findsOneWidget);
    });
  });
}
