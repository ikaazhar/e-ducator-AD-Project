// lib/screens/admin_screen.dart
//
// Skrin Pentadbir: urus semua profil pengguna.
// - Toggle is_active
// - Tukar peranan
// - Kemas kini department_unit
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<UserProfile>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadProfiles();
  }

  Future<List<UserProfile>> _loadProfiles() async {
    if (SupabaseConfig.isPlaceholder) {
      return [
        const UserProfile(
          id: 'mock-1',
          fullName: 'Admin Demo',
          email: 'admin@ikmjb.edu.my',
          role: 'Admin',
          departmentUnit: 'DGS',
        ),
        const UserProfile(
          id: 'mock-2',
          fullName: 'Pensyarah Demo',
          email: 'lecturer@ikmjb.edu.my',
          role: 'Lecturer',
          departmentUnit: 'DGS',
        ),
        const UserProfile(
          id: 'mock-3',
          fullName: 'Pengguna Tidak Aktif',
          email: 'inactive@ikmjb.edu.my',
          role: 'Lecturer',
          departmentUnit: 'DPP',
          isActive: false,
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
    await Supabase.instance.client.from('profiles').update(updates).eq('id', user.id);
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadProfiles());
    await _future;
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
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
          decoration: const InputDecoration(labelText: 'Kod jabatan (cth: DGS)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
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
