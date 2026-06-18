// lib/widgets/app_scaffold.dart
//
// Pembungkus Scaffold dengan susun atur bar sisi untuk desktop/web dan laci
// navigasi untuk mobile.
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../models/user_profile.dart';

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
    final role = context.watch<UserProvider>().profile?.role ?? '';
    final user = context.watch<UserProvider>().profile;
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';
    final showSidebar = MediaQuery.of(context).size.width >= 800;
    final canGoBack = Navigator.of(context).canPop();
    final scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
      drawer: showSidebar
          ? null
          : Drawer(
              width: 240,
              child: _SidebarContent(
                role: role,
                user: user,
                currentRoute: currentRoute,
                onNavigate: (route) {
                  Navigator.of(context).pop();
                  if (route != currentRoute) {
                    Navigator.of(context).pushReplacementNamed(route);
                  }
                },
                onSignOut: () => _handleSignOut(context),
              ),
            ),
      backgroundColor: AppTheme.slate,
      body: SafeArea(
        child: Row(
          children: [
            if (showSidebar)
              SizedBox(
                width: 240,
                child: _SidebarContent(
                  role: role,
                  user: user,
                  currentRoute: currentRoute,
                  onNavigate: (route) {
                    if (route != currentRoute) {
                      Navigator.of(context).pushReplacementNamed(route);
                    }
                  },
                  onSignOut: () => _handleSignOut(context),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: AppTheme.slateBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (canGoBack)
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: AppTheme.navy,
                            tooltip: 'Kembali',
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          )
                        else if (!showSidebar)
                          IconButton(
                            icon: const Icon(Icons.menu),
                            color: AppTheme.navy,
                            tooltip: 'Menu navigasi',
                            onPressed: () {
                              scaffoldKey.currentState?.openDrawer();
                            },
                          ),
                        if (canGoBack || !showSidebar) const SizedBox(width: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppTheme.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (actions != null) ...actions!,
                        if (showSignOut) _NotificationBell(user: user),
                        if (showSignOut)
                          IconButton(
                            tooltip: 'Log Keluar',
                            icon: const Icon(Icons.logout),
                            color: AppTheme.navy,
                            onPressed: () => _handleSignOut(context),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    context.read<UserProvider>().clearSession();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }
}

class _SidebarContent extends StatelessWidget {
  final String role;
  final UserProfile? user;
  final String currentRoute;
  final void Function(String route) onNavigate;
  final VoidCallback onSignOut;

  const _SidebarContent({
    required this.role,
    required this.user,
    required this.currentRoute,
    required this.onNavigate,
    required this.onSignOut,
  });

  static const _allRoles = [
    'Lecturer',
    'Ketua Program',
    'Ketua Jabatan',
    'Timbalan Pengarah Akademik',
    'Admin',
  ];

  List<_NavItem> get _items => [
        _NavItem(
          route: '/',
          icon: Icons.dashboard,
          label: 'Papan Pemuka',
          allowedRoles: _allRoles,
        ),
        _NavItem(
          route: '/timetable',
          icon: Icons.calendar_month,
          label: 'Jadual Waktu',
          allowedRoles: ['Lecturer'],
        ),
        _NavItem(
          route: '/timetable-upload',
          icon: Icons.upload_file,
          label: 'Muat Naik Jadual',
          allowedRoles: ['Admin', 'Ketua Program', 'Ketua Jabatan'],
        ),
        _NavItem(
          route: '/discipline',
          icon: Icons.report_problem,
          label: 'Laporan Disiplin',
          allowedRoles: [
            'Lecturer',
            'Ketua Program',
            'Ketua Jabatan',
            'Admin',
          ],
        ),
        _NavItem(
          route: '/reporting',
          icon: Icons.bar_chart,
          label: 'Laporan Kehadiran',
          allowedRoles: [
            'Lecturer',
            'Ketua Program',
            'Ketua Jabatan',
            'Timbalan Pengarah Akademik',
            'Admin',
          ],
        ),
        _NavItem(
          route: '/booking',
          icon: Icons.meeting_room,
          label: 'Tempahan Bilik',
          allowedRoles: _allRoles,
        ),
        _NavItem(
          route: '/admin',
          icon: Icons.manage_accounts,
          label: 'Urus Pengguna',
          allowedRoles: ['Admin'],
        ),
        _NavItem(
          route: '/admin-booking-monitor',
          icon: Icons.analytics_outlined,
          label: 'Pemantauan Tempahan Bilik',
          allowedRoles: ['Admin'],
        ),
        _NavItem(
          route: '/admin-rooms',
          icon: Icons.door_front_door,
          label: 'Urus Bilik',
          allowedRoles: ['Admin'],
        ),
        _NavItem(
          route: '/student-upload',
          icon: Icons.upload_file_outlined,
          label: 'Muat Naik Data Pelajar',
          allowedRoles: ['Admin', 'Ketua Jabatan'],
        ),
        _NavItem(
          route: '/student-classes',
          icon: Icons.groups_outlined,
          label: 'Urus Kelas Pelajar',
          allowedRoles: ['Admin', 'Ketua Jabatan'],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final items = _items.where((item) => item.allowedRoles.contains(role)).toList();

    return Container(
      color: AppTheme.navy,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.navyDark)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/ikm_logo.png',
                  height: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'E-ducator',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'IKM Johor Bahru',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final active = item.route == currentRoute;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Material(
                    color: active ? AppTheme.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      splashColor: Colors.white12,
                      onTap: () => onNavigate(item.route),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 18,
                              color: active ? AppTheme.navy : Colors.white60,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: active ? AppTheme.navy : Colors.white60,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(color: AppTheme.navyDark, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? 'Pengguna',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.role ?? 'Tetamu',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Keluar'),
                  onPressed: onSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatefulWidget {
  final UserProfile? user;

  const _NotificationBell({Key? key, required this.user}) : super(key: key);

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (widget.user == null) {
      if (!mounted) return;
      setState(() {
        _notifications = [];
        _computeUnread();
      });
      return;
    }

    final notifications = await _fetchNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _computeUnread();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchNotifications() async {
    if (widget.user == null) return [];
    return _notificationService.fetchRowsForUser(widget.user!.id);
  }
  void _computeUnread() {
    _unreadCount =
        _notifications.where((item) => !_isRead(item['is_read'])).length;
  }

  Future<void> _openNotificationPanel(BuildContext context) async {
    final hostContext = context;
    final selectedNotification = await showGeneralDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black26,
      barrierLabel: 'Tutup notifikasi',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 380,
            child: Material(
              color: Colors.white,
              shape: const RoundedRectangleBorder(),
              child: _buildNotificationPanel(context, hostContext),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOut))
              .animate(animation),
          child: child,
        );
      },
    );

    if (!mounted || selectedNotification == null) return;
    await _openNotificationDetail(hostContext, selectedNotification);
  }

  Widget _buildNotificationPanel(
    BuildContext panelContext,
    BuildContext hostContext,
  ) {
    final sorted = [..._notifications];
    sorted.sort((a, b) {
      final levelA = a['warning_level'] as int? ?? 0;
      final levelB = b['warning_level'] as int? ?? 0;
      final levelCompare = levelB.compareTo(levelA);
      if (levelCompare != 0) return levelCompare;
      final createdA = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final createdB = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return createdB.compareTo(createdA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Notifikasi',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.navy,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _markAllRead,
                child: const Text(
                  'Tandakan Semua Dibaca',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.navy),
                onPressed: () => Navigator.of(panelContext).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.notifications_none,
                            size: 48, color: AppTheme.textMuted),
                        SizedBox(height: 8),
                        Text(
                          'Tiada notifikasi amaran.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: sorted
                        .map((notification) => _buildNotificationRow(
                              panelContext,
                              hostContext,
                              notification,
                            ))
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildGroupSection(
    BuildContext panelContext,
    BuildContext hostContext,
    int level,
    List<Map<String, dynamic>> items,
  ) {
    final color =
        level == 3 ? AppTheme.tidakHadir : level == 2 ? AppTheme.ck : AppTheme.mc;
    final icon =
        level == 3 ? Icons.error : level == 2 ? Icons.warning : Icons.info_outline;
    final label = 'Amaran Tahap $level';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          color: color.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        ...items
            .map(
              (notification) => _buildNotificationRow(
                panelContext,
                hostContext,
                notification,
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildNotificationRow(
    BuildContext panelContext,
    BuildContext hostContext,
    Map<String, dynamic> notification,
  ) {
    final isRead = _isRead(notification['is_read']);
    final level = _warningLevel(notification);
    final notifType = notification['notification_type']?.toString() ?? '';

    // Determine if this is a booking notification
    final isBookingNotif = notifType.startsWith('booking_');

    // Icon and color based on type
    Color badgeColor;
    IconData badgeIcon;
    String title;

    if (isBookingNotif) {
      switch (notifType) {
        case 'booking_cancelled':
          badgeColor = Colors.red;
          badgeIcon = Icons.cancel_outlined;
          title = 'Tempahan Dibatalkan';
          break;
        case 'booking_reminder_today':
          badgeColor = AppTheme.teal;
          badgeIcon = Icons.today;
          title = 'Peringatan Hari Ini';
          break;
        case 'booking_reminder_tomorrow':
          badgeColor = Colors.blue;
          badgeIcon = Icons.event_outlined;
          title = 'Peringatan Esok';
          break;
        default:
          badgeColor = Colors.grey;
          badgeIcon = Icons.info_outline;
          title = _notificationTitle(notification);
      }
    } else {
      badgeColor = level == 3
          ? AppTheme.tidakHadir
          : level == 2
              ? AppTheme.ck
              : AppTheme.mc;
      badgeIcon = level == 3
          ? Icons.error
          : level == 2
              ? Icons.warning
              : Icons.info_outline;
      title = _notificationTitle(notification);
    }

    final createdAt = notification['created_at']?.toString();
    final parsedDate = DateTime.tryParse(createdAt ?? '');
    final formattedDate = parsedDate == null
        ? ''
        : DateFormat('d MMM yyyy', 'ms').format(parsedDate);
    final message = isBookingNotif
        ? (notification['message']?.toString() ?? '')
        : _notificationMessage(notification);

    return InkWell(
      onTap: () => _onNotificationTap(panelContext, notification),
      child: Container(
        color: isRead ? Colors.white : AppTheme.teal.withOpacity(0.03),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(badgeIcon, color: badgeColor, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: isRead ? AppTheme.textMuted : AppTheme.navy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: isRead ? AppTheme.textMuted : AppTheme.textDark,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.teal,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onNotificationTap(
    BuildContext panelContext,
    Map<String, dynamic> notification,
  ) async {
    final user = widget.user;
    final id = notification['id'];

    // Optimistic local update
    if (mounted) {
      final index = _notifications.indexWhere((item) => item['id'] == id);
      if (index != -1) {
        setState(() {
          _notifications[index] = {..._notifications[index], 'is_read': true};
          _computeUnread();
        });
      }
    }

    Navigator.of(panelContext).pop(notification);

    if (user == null || id == null) return;
    try {
      await _notificationService.markNotificationRead(id: id, user: user);
      final latest = await _fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = latest;
          _computeUnread();
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menandakan notifikasi sebagai dibaca.'),
          backgroundColor: AppTheme.tidakHadir,
        ),
      );
    }
  }

  Future<void> _markAllRead() async {
    if (widget.user == null) return;
    if (mounted) {
      setState(() {
        _notifications =
            _notifications.map((item) => {...item, 'is_read': true}).toList();
        _computeUnread();
      });
    }
    try {
      await _notificationService.markAllAsRead(widget.user!.id);
      final latest = await _fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = latest;
          _computeUnread();
        });
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menandakan notifikasi sebagai dibaca.'),
          backgroundColor: AppTheme.tidakHadir,
        ),
      );
    }
  }

  Future<void> _openNotificationDetail(
    BuildContext context,
    Map<String, dynamic> notification,
  ) {
    final level = _warningLevel(notification);
    final canOpenCriticalList =
        level == 3 && widget.user?.role == 'Ketua Program';
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _NotificationDetailPage(
          title: _notificationTitle(notification),
          message: _notificationMessage(notification),
          rawMessage:
              notification['message']?.toString() ?? 'Tiada butiran notifikasi.',
          level: level,
          createdAt:
              DateTime.tryParse(notification['created_at']?.toString() ?? '') ??
                  DateTime.now(),
          isBookingNotification:
              (notification['notification_type']?.toString() ?? '')
                  .startsWith('booking_'),
          recommendedAction: _recommendedAction(level),
          canOpenCriticalList: canOpenCriticalList,
        ),
      ),
    );
  }

  String _recommendedAction(int level) {
    switch (level) {
      case 1:
        return 'Pantau kehadiran pelajar dan beri peringatan awal jika perlu.';
      case 2:
        return 'Maklumkan kepada pihak berkaitan untuk tindakan awal.';
      case 3:
        return 'Surat amaran rasmi perlu diuruskan oleh Ketua Program mengikut prosedur IKM.';
      default:
        return 'Sila semak rekod kehadiran pelajar dan ambil tindakan susulan.';
    }
  }

  Color _warningLevelColor(int level) {
    if (level == 3) return AppTheme.tidakHadir;
    if (level == 2) return AppTheme.ck;
    if (level == 1) return AppTheme.mc;
    return AppTheme.navy;
  }

  int _warningLevel(Map<String, dynamic> notification) {
    final rawLevel = notification['warning_level'];
    if (rawLevel is int) return rawLevel;
    if (rawLevel is num) return rawLevel.toInt();
    if (rawLevel is String) {
      final parsed = int.tryParse(rawLevel);
      if (parsed != null) return parsed;
    }

    final text = [
      notification['title']?.toString() ?? '',
      notification['message']?.toString() ?? '',
    ].join(' ');
    final match = RegExp(
      r'(?:Tahap|Level)\s*([123])',
      caseSensitive: false,
    ).firstMatch(text);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  String _notificationTitle(Map<String, dynamic> notification) {
    final notifType = notification['notification_type']?.toString() ?? '';
    if (!notifType.startsWith('booking_')) {
      final level = _warningLevel(notification);
      return level > 0 ? 'Amaran Tahap $level' : 'Amaran Kehadiran';
    }

    switch (notifType) {
      case 'booking_cancelled':
        return 'Tempahan Dibatalkan';
      case 'booking_reminder_today':
        return 'Peringatan Hari Ini';
      case 'booking_reminder_tomorrow':
        return 'Peringatan Esok';
      default:
        final title = notification['title']?.toString().trim() ?? '';
        return title.isEmpty ? 'Notifikasi Tempahan' : title;
    }
  }

  String _notificationMessage(Map<String, dynamic> notification) {
    final raw = notification['message']?.toString().trim() ?? '';
    final level = _warningLevel(notification);
    if (raw.isEmpty) {
      return 'Sila semak rekod kehadiran pelajar dan ambil tindakan susulan.';
    }

    final prefix = RegExp(
      '^Amaran\\s+Tahap\\s+$level\\s*:\\s*',
      caseSensitive: false,
    );
    return raw.replaceFirst(prefix, '');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openNotificationPanel(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined, color: AppTheme.navy, size: 22),
            if (_unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppTheme.tidakHadir,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDetailPage extends StatelessWidget {
  final String title;
  final String message;
  final String rawMessage;
  final int level;
  final DateTime createdAt;
  final bool isBookingNotification;
  final String recommendedAction;
  final bool canOpenCriticalList;

  const _NotificationDetailPage({
    required this.title,
    required this.message,
    required this.rawMessage,
    required this.level,
    required this.createdAt,
    required this.isBookingNotification,
    required this.recommendedAction,
    required this.canOpenCriticalList,
  });

  @override
  Widget build(BuildContext context) {
    final parsedStudent = _extractStudentName(rawMessage);
    final parsedPercent = _extractAttendancePercent(rawMessage);

    return Scaffold(
      backgroundColor: AppTheme.slate,
      appBar: AppBar(
        title: Text(
          isBookingNotification ? title : 'Butiran Amaran Kehadiran',
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.slateBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _warningLevelColor(level).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isBookingNotification || level <= 0
                          ? title
                          : 'Amaran Tahap $level',
                      style: TextStyle(
                        color: _warningLevelColor(level),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!isBookingNotification && parsedStudent != null)
                    _detailRow('Nama Pelajar', parsedStudent),
                  if (!isBookingNotification && parsedPercent != null)
                    _detailRow(
                      'Peratus Kehadiran',
                      '${parsedPercent.toStringAsFixed(1)}%',
                    ),
                  if (!isBookingNotification)
                    _detailRow(
                      'Tahap Amaran',
                      level > 0 ? 'Tahap $level' : 'Tidak dinyatakan',
                    ),
                  _detailRow(
                    'Tarikh Notifikasi',
                    DateFormat('d MMMM yyyy', 'ms').format(createdAt),
                  ),
                  _detailRow(
                    'Mesej',
                    isBookingNotification ? rawMessage : message,
                  ),
                  _detailRow('Tindakan Disyorkan', recommendedAction),
                  const SizedBox(height: 16),
                  const Text(
                    'Notifikasi ini dijana secara automatik oleh sistem E-ducator.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (canOpenCriticalList) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('Buka Senarai Pelajar Kritikal'),
                        onPressed: () {
                          Navigator.of(context).pushNamed('/reporting');
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _warningLevelColor(int level) {
    if (level == 3) return AppTheme.tidakHadir;
    if (level == 2) return AppTheme.ck;
    if (level == 1) return AppTheme.mc;
    return AppTheme.navy;
  }

  static Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              '$label :',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String? _extractStudentName(String message) {
    final match = RegExp(r'^Kehadiran\s+(.+?)\s+ialah\s+[0-9]+(?:\.[0-9]+)?%')
        .firstMatch(message);
    return match?.group(1)?.trim();
  }

  static double? _extractAttendancePercent(String message) {
    final match =
        RegExp(r'ialah\s+([0-9]+(?:\.[0-9]+)?)%').firstMatch(message);
    return double.tryParse(match?.group(1) ?? '');
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  final List<String> allowedRoles;

  const _NavItem({
    required this.route,
    required this.icon,
    required this.label,
    required this.allowedRoles,
  });
}

bool _isRead(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes' || normalized == 't';
  }
  return false;
}
