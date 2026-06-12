import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/approval_request.dart';
import '../../models/user_profile.dart';
import '../../providers/user_provider.dart';
import '../../services/user_management_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserManagementService _service = UserManagementService();

  List<ApprovalRequest> _pending = [];
  List<UserProfile> _active = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final approverRole =
          context.read<UserProvider>().profile?.role ?? '';
      final pending = await _service.getPendingUsers(approverRole);
      final active  = await _service.getActiveUsers(approverRole);
      setState(() {
        _pending = pending;
        _active  = active;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _approve(ApprovalRequest req) async {
    final approverId =
        context.read<UserProvider>().profile?.id ?? '';
    try {
      await _service.approveUser(
        userId:        req.id,
        requestedRole: req.requestedRole,
        approverId:    approverId,
      );
      _showSnack('${req.fullName} telah diluluskan.', Colors.green);
      await _loadData();
    } catch (e) {
      _showSnack('Gagal: $e', Colors.red);
    }
  }

  Future<void> _reject(ApprovalRequest req) async {
    final confirmed = await _confirmDialog(
      'Tolak Permohonan',
      'Adakah anda pasti ingin menolak permohonan ${req.fullName}?',
    );
    if (!confirmed) return;

    final approverId =
        context.read<UserProvider>().profile?.id ?? '';
    try {
      await _service.rejectUser(userId: req.id, approverId: approverId);
      _showSnack('${req.fullName} telah ditolak.', Colors.orange);
      await _loadData();
    } catch (e) {
      _showSnack('Gagal: $e', Colors.red);
    }
  }

  Future<void> _deactivate(UserProfile user) async {
    final confirmed = await _confirmDialog(
      'Nyahaktifkan Pengguna',
      'Adakah anda pasti ingin nyahaktifkan ${user.fullName}?',
    );
    if (!confirmed) return;

    try {
      await _service.deactivateUser(user.id);
      _showSnack('${user.fullName} telah dinyahaktifkan.', Colors.orange);
      await _loadData();
    } catch (e) {
      _showSnack('Gagal: $e', Colors.red);
    }
  }

  Future<void> _reassignRole(UserProfile user) async {
    final approverRole =
        context.read<UserProvider>().profile?.role ?? '';
    final allowed = _service.getAllowedRoles(approverRole)
        .where((r) => r != user.role)
        .toList();

    if (allowed.isEmpty) {
      _showSnack('Tiada peranan lain yang boleh ditetapkan.', Colors.grey);
      return;
    }

    String? selectedRole = allowed.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tukar Peranan — ${user.fullName}'),
        content: StatefulBuilder(
          builder: (ctx, setInner) => DropdownButton<String>(
            value: selectedRole,
            isExpanded: true,
            items: allowed
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setInner(() => selectedRole = v),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan')),
        ],
      ),
    );

    if (confirmed != true || selectedRole == null) return;

    final approverId =
        context.read<UserProvider>().profile?.id ?? '';
    try {
      await _service.reassignRole(
        userId:    user.id,
        newRole:   selectedRole!,
        approverId: approverId,
      );
      _showSnack('Peranan ${user.fullName} dikemas kini.', Colors.green);
      await _loadData();
    } catch (e) {
      _showSnack('Gagal: $e', Colors.red);
    }
  }

  Future<bool> _confirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Ya, Teruskan')),
            ],
          ),
        ) ??
        false;
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengurusan Pengguna Baru'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Menunggu Kelulusan'),
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _badge(_pending.length),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Pengguna Aktif'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingTab(),
                    _buildActiveTab(),
                  ],
                ),
    );
  }

  Widget _badge(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      );

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loadData, child: const Text('Cuba Semula')),
          ],
        ),
      );

  // ─── Pending Tab ─────────────────────────────────────────────────────────

  Widget _buildPendingTab() {
    if (_pending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
            SizedBox(height: 12),
            Text('Tiada permohonan menunggu kelulusan.'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _pendingCard(_pending[i]),
      ),
    );
  }

  Widget _pendingCard(ApprovalRequest req) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    req.fullName.isNotEmpty ? req.fullName[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(req.email,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip(Icons.work_outline, req.requestedRole, Colors.blue),
                const SizedBox(width: 8),
                if (req.departmentUnit != null)
                  _infoChip(Icons.apartment, req.departmentUnit!, Colors.teal),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(req),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Tolak'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(req),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Luluskan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Active Tab ──────────────────────────────────────────────────────────

  Widget _buildActiveTab() {
    if (_active.isEmpty) {
      return const Center(child: Text('Tiada pengguna aktif.'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _active.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _activeCard(_active[i]),
      ),
    );
  }

  Widget _activeCard(UserProfile user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.green.shade700),
          ),
        ),
        title: Text(user.fullName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            _infoChip(Icons.work_outline, user.role, Colors.blue),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'reassign') _reassignRole(user);
            if (val == 'deactivate') _deactivate(user);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'reassign',
              child: Row(children: [
                Icon(Icons.swap_horiz, size: 18),
                SizedBox(width: 8),
                Text('Tukar Peranan'),
              ]),
            ),
            const PopupMenuItem(
              value: 'deactivate',
              child: Row(children: [
                Icon(Icons.block, size: 18, color: Colors.red),
                SizedBox(width: 8),
                Text('Nyahaktifkan', style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}