// lib/screens/dashboards/_dashboard_shell.dart
//
// Templat papan pemuka dikongsi untuk semua peranan.
// Memaparkan kad navigasi modul dan ucapan kepada pengguna.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';

class DashboardLink {
  final String title;
  final String description;
  final IconData icon;
  final String route;
  const DashboardLink({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });
}

class DashboardShell extends StatelessWidget {
  final String roleTitle;
  final List<DashboardLink> links;

  const DashboardShell({
    super.key,
    required this.roleTitle,
    required this.links,
  });

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProvider>().profile;

    return AppScaffold(
      title: 'E-ducator — $roleTitle',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang, ${profile?.fullName ?? "Pengguna"}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile?.role ?? ""} • ${profile?.departmentUnit ?? "-"}',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxis = constraints.maxWidth >= 900
                        ? 3
                        : constraints.maxWidth >= 600
                            ? 2
                            : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: links.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxis,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 170,
                      ),
                      itemBuilder: (_, i) => _moduleCard(context, links[i]),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moduleCard(BuildContext context, DashboardLink link) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, link.route),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(link.icon, color: AppTheme.teal),
              ),
              const Spacer(),
              Text(
                link.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                link.description,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
