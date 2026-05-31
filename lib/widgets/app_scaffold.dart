// lib/widgets/app_scaffold.dart
//
// Pembungkus Scaffold lazim dengan AppBar dan butang log keluar.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showSignOut;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showSignOut = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          if (showSignOut)
            IconButton(
              tooltip: 'Log Keluar',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await AuthService().signOut();
                if (context.mounted) {
                  context.read<UserProvider>().clearSession();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (_) => false,
                  );
                }
              },
            ),
        ],
      ),
      backgroundColor: AppTheme.slate,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
