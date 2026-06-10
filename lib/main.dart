// lib/main.dart
//
// Titik masuk aplikasi E-ducator. Memulakan Supabase, MaterialApp, dan
// menetapkan UserProvider serta jadual penghalaan untuk semua modul.
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'providers/user_provider.dart';
import 'screens/admin_booking_monitor_screen.dart';
import 'screens/admin_room_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/discipline_form_screen.dart';
import 'screens/discipline_list_screen.dart';
import 'screens/hierarchy_router.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reporting_dashboard_screen.dart';
import 'screens/room_booking_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/timetable_upload_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ms', null);

  if (!SupabaseConfig.isPlaceholder) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  runApp(const EducatorApp());
}

class EducatorApp extends StatelessWidget {
  const EducatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserProvider()..loadProfile(),
      child: MaterialApp(
        title: 'E-ducator — IKM Johor Bahru',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: '/',
        routes: {
          '/': (_) => const HierarchyRouter(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/admin': (_) => const AdminScreen(),
          '/admin-booking-monitor': (_) => const AdminBookingMonitorScreen(),
          '/admin-rooms': (_) => const AdminRoomScreen(),
          '/timetable': (_) => const TimetableScreen(),
          '/timetable-upload': (_) => const TimetableUploadScreen(),
          '/discipline': (_) => const DisciplineListScreen(),
          '/discipline-form': (_) => const DisciplineFormScreen(),
          '/reporting': (_) => const ReportingDashboardScreen(),
          '/booking': (_) => const RoomBookingScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/attendance') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => AttendanceScreen(
                timetableId: args['timetableId'] as String,
                subjectName: args['subjectName'] as String,
                subjectCode: args['subjectCode'] as String,
                departmentUnit: args['departmentUnit'] as String,
                attendanceDate: args['attendanceDate'] as String,
                userId: args['userId'] as String,
                initialReadOnly: (args['isReadOnly'] as bool?) ?? false,
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
