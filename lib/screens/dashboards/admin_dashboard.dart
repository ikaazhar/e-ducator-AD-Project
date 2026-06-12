// lib/screens/dashboards/admin_dashboard.dart
//
// Papan pemuka untuk peranan Admin.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '_dashboard_shell.dart';

// Add these imports at the top:
import '../../services/user_management_service.dart'; // NEW
import 'user_management_screen.dart'; // NEW

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  int _totalUsers = 0;
  int _totalRooms = 0;
  int _totalStudents = 0;
  int _totalTimetableEntries = 0;
  // Add to state class:
  int _pendingCount = 0; // NEW
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    // Add to initState():
    _loadPendingCount(); // NEW
  }

  // Add these methods:
  Future<void> _loadPendingCount() async {
    try {
      final rows = await UserManagementService().getPendingUsers('Ketua Program');
      if (mounted) setState(() => _pendingCount = rows.length);
    } catch (_) {}
  }

  void _openUserManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserManagementScreen()),
    );
    _loadPendingCount();
  }

  Future<void> _loadDashboard() async {
    final client = Supabase.instance.client;

    try {
      final usersFuture = client.from('profiles').select('id');
      final roomsFuture = client
          .from('rooms')
          .select('id')
          .eq('status', 'Available');
      final studentsFuture = client.from('students').select('id');
      final timetableFuture = client.from('timetable').select('id');
      final activityFuture = client
          .from('profiles')
          .select('full_name, role, created_at')
          .order('created_at', ascending: false)
          .limit(5);

      final userRows = _rowsFrom(await usersFuture);
      final roomRows = _rowsFrom(await roomsFuture);
      final studentRows = _rowsFrom(await studentsFuture);
      final timetableRows = _rowsFrom(await timetableFuture);
      final activityRows = _rowsFrom(await activityFuture);

      final recentActivity = activityRows.map((row) {
        final name = row['full_name']?.toString() ?? 'Pengguna';
        final role = row['role']?.toString() ?? '';
        final createdAt = row['created_at']?.toString() ?? '';
        final createdAtDate = DateTime.tryParse(createdAt);
        return {
          'name': name,
          'action': 'mendaftar sebagai $role',
          'time': createdAtDate == null ? '' : _timeAgo(createdAtDate),
          'initials': _initials(name),
        };
      }).toList();

      if (mounted) {
        setState(() {
          _totalUsers = userRows.length;
          _totalRooms = roomRows.length;
          _totalStudents = studentRows.length;
          _totalTimetableEntries = timetableRows.length;
          _recentActivity = recentActivity;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _totalUsers = 0;
          _totalRooms = 0;
          _totalStudents = 0;
          _totalTimetableEntries = 0;
          _recentActivity = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  static List<Map<String, dynamic>> _rowsFrom(dynamic response) {
    if (response == null) return [];
    return (response as List).cast<Map<String, dynamic>>();
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Baru sahaja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minit lepas';
    if (diff.inHours < 24) return '${diff.inHours} jam lepas';
    if (diff.inDays == 1) return 'Semalam';
    return '${diff.inDays} hari lepas';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Papan Pemuka',
      actions: [
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/timetable-upload'),
          icon: const Icon(Icons.upload_file, size: 16),
          label: const Text('Muat Naik Jadual'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.navy,
            side: const BorderSide(color: AppTheme.slateBorder),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/admin'),
          icon: const Icon(Icons.manage_accounts, size: 16),
          label: const Text('Urus Pengguna'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.navy,
            side: const BorderSide(color: AppTheme.slateBorder),
          ),
        ),
        Stack(
          children: [
            IconButton(
              tooltip: 'Sahkan Pengguna Baru',
              icon: const Icon(Icons.manage_accounts),
              onPressed: _openUserManagement,
            ),
            if (_pendingCount > 0)
              Positioned(
                right: 6, top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text('$_pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/admin-rooms'),
          icon: const Icon(Icons.door_front_door, size: 16),
          label: const Text('Urus Bilik'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.navy,
            foregroundColor: Colors.white,
          ),
        ),
      ],
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.teal),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pusat Kawalan Admin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pengurusan pengguna, bilik, jadual dan data sistem.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 900) {
                        return Row(
                          children: [
                            Expanded(
                              child: DashStatCard(
                                title: 'JUMLAH PENGGUNA',
                                value: '$_totalUsers',
                                subtitle: 'Pengguna berdaftar',
                                icon: Icons.people,
                                iconColor: AppTheme.teal,
                                onTap: () => Navigator.pushNamed(context, '/admin'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'BILIK TERSEDIA',
                                value: '$_totalRooms',
                                subtitle: 'Status: Available',
                                icon: Icons.meeting_room,
                                iconColor: AppTheme.navy,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/admin-rooms'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'JUMLAH PELAJAR',
                                value: '$_totalStudents',
                                subtitle: 'Dalam sistem',
                                icon: Icons.school_outlined,
                                iconColor: AppTheme.hadir,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DashStatCard(
                                title: 'ENTRI JADUAL',
                                value: '$_totalTimetableEntries',
                                subtitle: 'Slot jadual aktif',
                                icon: Icons.calendar_month,
                                iconColor: AppTheme.mc,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/timetable-upload'),
                              ),
                            ),
                          ],
                        );
                      }

                      return GridView.count(
                        crossAxisCount: constraints.maxWidth >= 600 ? 2 : 1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 110,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          DashStatCard(
                            title: 'JUMLAH PENGGUNA',
                            value: '$_totalUsers',
                            subtitle: 'Pengguna berdaftar',
                            icon: Icons.people,
                            iconColor: AppTheme.teal,
                            onTap: () => Navigator.pushNamed(context, '/admin'),
                          ),
                          DashStatCard(
                            title: 'BILIK TERSEDIA',
                            value: '$_totalRooms',
                            subtitle: 'Status: Available',
                            icon: Icons.meeting_room,
                            iconColor: AppTheme.navy,
                            onTap: () =>
                                Navigator.pushNamed(context, '/admin-rooms'),
                          ),
                          DashStatCard(
                            title: 'JUMLAH PELAJAR',
                            value: '$_totalStudents',
                            subtitle: 'Dalam sistem',
                            icon: Icons.school_outlined,
                            iconColor: AppTheme.hadir,
                          ),
                          DashStatCard(
                            title: 'ENTRI JADUAL',
                            value: '$_totalTimetableEntries',
                            subtitle: 'Slot jadual aktif',
                            icon: Icons.calendar_month,
                            iconColor: AppTheme.mc,
                            onTap: () =>
                                Navigator.pushNamed(context, '/timetable-upload'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      final modules = [
                        {
                          'label': 'Jadual Waktu',
                          'icon': Icons.calendar_month,
                        },
                        {
                          'label': 'Muat Naik Jadual',
                          'icon': Icons.upload_file,
                        },
                        {
                          'label': 'Kehadiran',
                          'icon': Icons.how_to_reg,
                        },
                        {
                          'label': 'Laporan Disiplin',
                          'icon': Icons.report_problem,
                        },
                        {
                          'label': 'Laporan Kehadiran',
                          'icon': Icons.bar_chart,
                        },
                        {
                          'label': 'Tempahan Bilik',
                          'icon': Icons.meeting_room,
                        },
                      ];

                      return isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const DashSectionHeader(
                                            title: 'Aktiviti Terkini',
                                          ),
                                          const SizedBox(height: 12),
                                          if (_recentActivity.isEmpty)
                                            const Padding(
                                              padding:
                                                  EdgeInsets.symmetric(vertical: 16),
                                              child: Center(
                                                child: Text(
                                                  'Tiada aktiviti terkini.',
                                                  style: TextStyle(
                                                    color: AppTheme.textMuted,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Column(
                                              children: _recentActivity
                                                  .map(
                                                    (activity) => ActivityItem(
                                                      initials: activity['initials']
                                                          as String,
                                                      name:
                                                          activity['name'] as String,
                                                      action:
                                                          activity['action'] as String,
                                                      timeAgo:
                                                          activity['time'] as String,
                                                      color: AppTheme.navy,
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const Text(
                                            'Modul Sistem',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.navy,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          ...modules.map(
                                            (module) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(vertical: 8),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    module['icon'] as IconData,
                                                    size: 18,
                                                    color: AppTheme.navy,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      module['label'] as String,
                                                      style: const TextStyle(
                                                        color: AppTheme.textDark,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          AppTheme.teal.withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(20),
                                                    ),
                                                    child: const Text(
                                                      'Aktif',
                                                      style: TextStyle(
                                                        color: AppTheme.teal,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const DashSectionHeader(title: 'Aktiviti Terkini'),
                                        const SizedBox(height: 12),
                                        if (_recentActivity.isEmpty)
                                          const Padding(
                                            padding:
                                                EdgeInsets.symmetric(vertical: 16),
                                            child: Center(
                                              child: Text(
                                                'Tiada aktiviti terkini.',
                                                style: TextStyle(
                                                  color: AppTheme.textMuted,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Column(
                                            children: _recentActivity
                                                .map(
                                                  (activity) => ActivityItem(
                                                    initials:
                                                        activity['initials'] as String,
                                                    name: activity['name'] as String,
                                                    action:
                                                        activity['action'] as String,
                                                    timeAgo:
                                                        activity['time'] as String,
                                                    color: AppTheme.navy,
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          'Modul Sistem',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.navy,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ...modules.map(
                                          (module) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  module['icon'] as IconData,
                                                  size: 18,
                                                  color: AppTheme.navy,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    module['label'] as String,
                                                    style: const TextStyle(
                                                      color: AppTheme.textDark,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.teal.withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(20),
                                                  ),
                                                  child: const Text(
                                                    'Aktif',
                                                    style: TextStyle(
                                                      color: AppTheme.teal,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Tindakan Pantas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navy,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/admin'),
                              icon: const Icon(
                                Icons.manage_accounts,
                                size: 18,
                                color: AppTheme.teal,
                              ),
                              label: const Text('Urus Pengguna'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.navy,
                                side: const BorderSide(color: AppTheme.slateBorder),
                                alignment: Alignment.centerLeft,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: Stack(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _openUserManagement,
                                  icon: const Icon(Icons.manage_accounts, size: 18, color: Color.fromARGB(255, 10, 217, 76)),
                                  label: const Text('Sahkan Pengguna Baru'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.navy,
                                    side: const BorderSide(color: AppTheme.slateBorder),
                                    alignment: Alignment.centerLeft,
                                    minimumSize: const Size(double.infinity, 44),
                                  ),
                                ),
                                if (_pendingCount > 0)
                                  Positioned(
                                    right: 12, top: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                      child: Text('$_pendingCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/timetable-upload'),
                              icon: const Icon(
                                Icons.upload_file,
                                size: 18,
                                color: AppTheme.navy,
                              ),
                              label: const Text('Muat Naik Jadual'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.navy,
                                side: const BorderSide(color: AppTheme.slateBorder),
                                alignment: Alignment.centerLeft,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/reporting'),
                              icon: const Icon(
                                Icons.bar_chart,
                                size: 18,
                                color: AppTheme.hadir,
                              ),
                              label: const Text('Laporan Kehadiran'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.navy,
                                side: const BorderSide(color: AppTheme.slateBorder),
                                alignment: Alignment.centerLeft,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/booking'),
                              icon: const Icon(
                                Icons.meeting_room,
                                size: 18,
                                color: AppTheme.navy,
                              ),
                              label: const Text('Tempahan Bilik'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.navy,
                                side: const BorderSide(color: AppTheme.slateBorder),
                                alignment: Alignment.centerLeft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}