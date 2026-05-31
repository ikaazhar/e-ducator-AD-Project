// lib/screens/discipline_list_screen.dart
//
// Modul 2 — Halaman 1: Senarai Laporan Disiplin.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/discipline_report.dart';
import '../models/user_profile.dart';
import '../providers/user_provider.dart';
import '../services/discipline_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/severity_badge.dart';

class DisciplineListScreen extends StatefulWidget {
  const DisciplineListScreen({super.key});

  @override
  State<DisciplineListScreen> createState() => _DisciplineListScreenState();
}

class _DisciplineListScreenState extends State<DisciplineListScreen> {
  final _service = DisciplineService();
  late Future<List<DisciplineReport>> _future;
  String _search = '';
  String _severityFilter = 'Semua';
  String? _simulatedRole;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  UserProfile _effectiveUser(UserProfile actual) {
    if (_simulatedRole == null || _simulatedRole == actual.role) return actual;
    return actual.copyWith(role: _simulatedRole);
  }

  Future<List<DisciplineReport>> _load() async {
    final actual = context.read<UserProvider>().profile!;
    final effective = _effectiveUser(actual);
    return _service.fetchReports(effective);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Laporan Disiplin',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.teal,
        onPressed: () async {
          final ok = await Navigator.pushNamed(context, '/discipline-form');
          if (ok == true) _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Laporan Baru'),
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: FutureBuilder<List<DisciplineReport>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Ralat: ${snap.error}'));
                }
                final reports = (snap.data ?? const []).where(_match).toList();
                if (reports.isEmpty) {
                  return const Center(
                    child: Text('Tiada laporan disiplin.',
                        style: TextStyle(color: AppTheme.textMuted)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (_, i) => _reportCard(reports[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _match(DisciplineReport r) {
    if (_severityFilter != 'Semua' && r.severity != _severityFilter) return false;
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    return (r.studentName ?? '').toLowerCase().contains(q) ||
        r.issueType.toLowerCase().contains(q);
  }

  Widget _filterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari pelajar atau jenis isu...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String>(
              initialValue: _severityFilter,
              decoration: const InputDecoration(labelText: 'Tahap Keseriusan'),
              items: ['Semua', ...kSeverityLevels]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _severityFilter = v ?? 'Semua'),
            ),
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              initialValue: _simulatedRole,
              decoration: const InputDecoration(labelText: 'Simulasi Skop Peranan'),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('— Sebenar —')),
                ...['Lecturer', 'Ketua Program', 'Ketua Jabatan', 'Admin']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r))),
              ],
              onChanged: (v) {
                setState(() {
                  _simulatedRole = v;
                  _future = _load();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportCard(DisciplineReport r) {
    final df = DateFormat('d MMM yyyy', 'ms');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.studentName ?? r.studentId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.programId ?? "-"} • ${r.issueType}',
                    style: const TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  if ((r.notes ?? '').isNotEmpty)
                    Text(
                      r.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Dilaporkan oleh ${r.reporterName ?? "-"} • '
                    '${r.createdAt != null ? df.format(r.createdAt!) : "-"}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            SeverityBadge(severity: r.severity),
          ],
        ),
      ),
    );
  }
}
