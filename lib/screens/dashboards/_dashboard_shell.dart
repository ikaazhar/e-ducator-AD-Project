// lib/screens/dashboards/_dashboard_shell.dart
//
// Templat papan pemuka dikongsi untuk semua peranan.
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
    final greeting = profile?.fullName ?? 'Pengguna';

    return AppScaffold(
      title: 'Papan Pemuka',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleTitle,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selamat datang, $greeting. Pilih modul untuk bermula.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                if (links.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Tiada pautan tersedia untuk peranan ini.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                else
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
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 150,
                        ),
                        itemBuilder: (_, index) => _DashboardLinkCard(link: links[index]),
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
}

class DashStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const DashStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slateBorder),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

class DashSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DashSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.navy,
          ),
        ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.teal,
              textStyle: const TextStyle(fontSize: 13),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class ActivityItem extends StatelessWidget {
  final String initials;
  final String name;
  final String action;
  final String timeAgo;
  final Color color;

  const ActivityItem({
    super.key,
    required this.initials,
    required this.name,
    required this.action,
    required this.timeAgo,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.15),
            child: Text(
              initials,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                    children: [
                      TextSpan(
                        text: name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                      TextSpan(
                        text: ' $action',
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TodayClassItem extends StatelessWidget {
  final String timeRange;
  final String subjectName;
  final String classCode;
  final String room;
  final VoidCallback? onTap;

  const TodayClassItem({
    super.key,
    required this.timeRange,
    required this.subjectName,
    required this.classCode,
    required this.room,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                timeRange,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$classCode · $room',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLinkCard extends StatelessWidget {
  final DashboardLink link;

  const _DashboardLinkCard({
    super.key,
    required this.link,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.slateBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, link.route),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.teal.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(10),
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
              const SizedBox(height: 6),
              Text(
                link.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
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
