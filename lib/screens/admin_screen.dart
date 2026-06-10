// lib/screens/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import '../services/user_management_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import 'admin_booking_monitor_screen.dart';
import 'dashboards/user_management_screen.dart'; // NEW

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<UserProfile>> _future;
  int _pendingCount = 0; // NEW

  @override
  void initState() {
    super.initState();
    _future = _loadProfiles();
    _loadPendingCount(); // NEW
  }

  // NEW: load how many pending requests exist for the badge
  Future<void> _loadPendingCount() async {
    if (SupabaseConfig.isPlaceholder) return;
    try {
      final rows = await UserManagementService()
          .getPendingUsers('Admin');
      if (mounted) setState(() => _pendingCount = rows.length);
    } catch (_) {}
  }

  Future<List<UserProfile>> _loadProfiles() async {
    if (SupabaseConfig.isPlaceholder) {
      return [
        UserProfile(
          id: 'mock-1',
          fullName: 'Admin Demo',
          email: 'admin@ikmjb.edu.my',
          role: 'Admin',
          departmentUnit: 'DGS',
          isActive: true,
          approvalStatus: 'approved',
        ),
        UserProfile(
          id: 'mock-2',
          fullName: 'Pensyarah Demo',
          email: 'lecturer@ikmjb.edu.my',
          role: 'Lecturer',
          departmentUnit: 'DGS',
          isActive: true,
          approvalStatus: 'approved',
        ),
        UserProfile(
          id: 'mock-3',
          fullName: 'Pengguna Tidak Aktif',
          email: 'inactive@ikmjb.edu.my',
          role: 'Lecturer',
          departmentUnit: 'DPP',
          isActive: false,
          approvalStatus: 'approved',
        ),
      ];
    }
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .order('full_name');
    return (data as List)
        .map((r) => UserProfile.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> _update(UserProfile user, Map<String, dynamic> updates) async {
    if (SupabaseConfig.isPlaceholder) return;
    await Supabase.instance.client
        .from('profiles')
        .update(updates)
        .eq('id', user.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadProfiles());
    await _future;
    await _loadPendingCount(); // NEW: refresh badge too
  }

  // NEW: navigate to UserManagementScreen then refresh badge on return
  void _openUserManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserManagementScreen()),
    );
    _loadPendingCount();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Panel Pentadbir',
      actions: [
        IconButton(
          tooltip: 'Muat Semula',
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),

        // NEW: User Management button with pending badge
        Stack(
          children: [
            IconButton(
              tooltip: 'Pengurusan Pengguna',
              icon: const Icon(Icons.manage_accounts),
              onPressed: _openUserManagement,
            ),
            if (_pendingCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$_pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),

        IconButton(
          tooltip: 'Pantau Semua Tempahan',
          icon: const Icon(Icons.analytics_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminBookingMonitorScreen()),
          ),
        ),
        IconButton(
          tooltip: 'Urus Bilik',
          icon: const Icon(Icons.meeting_room),
          onPressed: () => Navigator.pushNamed(context, '/admin-rooms'),
        ),
      ],
      body: FutureBuilder<List<UserProfile>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Ralat: ${snap.error}'));
          }
          final users = snap.data ?? const [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                    columns: const [
                      DataColumn(label: Text('Nama')),
                      DataColumn(label: Text('E-mel')),
                      DataColumn(label: Text('Peranan')),
                      DataColumn(label: Text('Jabatan')),
                      DataColumn(label: Text('Status')),   // NEW: was 'Aktif'
                      DataColumn(label: Text('Aktif')),
                      DataColumn(label: Text('Tindakan')),
                    ],
                    rows: users.map((u) => _buildRow(u)).toList(),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  DataRow _buildRow(UserProfile u) {
    return DataRow(
      cells: [
        DataCell(Text(u.fullName)),
        DataCell(Text(u.email)),
        DataCell(Text(u.role)),
        DataCell(Text(u.departmentUnit ?? '-')),

        // NEW: approval status chip
        DataCell(_statusChip(u.approvalStatus)),

        DataCell(Switch(
          value: u.isActive,
          activeThumbColor: AppTheme.teal,
          onChanged: (v) async {
            await _update(u, {'is_active': v});
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(v
                    ? 'Akaun ${u.fullName} diaktifkan.'
                    : 'Akaun ${u.fullName} dinyahaktifkan.'),
              ),
            );
            _refresh();
          },
        )),

        DataCell(Row(
          children: [
            IconButton(
              tooltip: 'Tukar Peranan',
              icon: const Icon(Icons.swap_horiz, color: AppTheme.navy),
              onPressed: () => _showRoleDialog(u),
            ),
            IconButton(
              tooltip: 'Kemas kini Jabatan',
              icon: const Icon(Icons.apartment, color: AppTheme.navy),
              onPressed: () => _showUnitDialog(u),
            ),
          ],
        )),
      ],
    );
  }

  // NEW: colour-coded approval status chip
  Widget _statusChip(String status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Diluluskan';
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Ditolak';
        icon = Icons.cancel_outlined;
        break;
      case 'pending':
      default:
        color = Colors.orange;
        label = 'Menunggu';
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _showRoleDialog(UserProfile u) async {
    String role = u.role;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tukar Peranan'),
        content: StatefulBuilder(
          builder: (ctx, setSt) => DropdownButtonFormField<String>(
            initialValue: role,
            items: kRoleList
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setSt(() => role = v ?? role),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, role),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result != u.role) {
      await _update(u, {'role': result});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Peranan ${u.fullName} dikemaskini.')),
      );
      _refresh();
    }
  }

  Future<void> _showUnitDialog(UserProfile u) async {
    final ctrl = TextEditingController(text: u.departmentUnit ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kemas kini Jabatan / Unit'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(labelText: 'Kod jabatan (cth: DGS)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _update(u, {'department_unit': result});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jabatan dikemaskini.')),
      );
      _refresh();
    }
  }
}