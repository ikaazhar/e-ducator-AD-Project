// test/widget_test.dart
//
// Asas ujian widget E-ducator.
import 'package:e_ducator/screens/login_screen.dart';
import 'package:e_ducator/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:e_ducator/providers/user_provider.dart';

void main() {
  testWidgets('Skrin log masuk memaparkan tajuk E-ducator',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UserProvider(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('E-ducator'), findsOneWidget);
    expect(find.text('Log Masuk'), findsOneWidget);
  });
}
