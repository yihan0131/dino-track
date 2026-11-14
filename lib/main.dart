import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/station_details_screen.dart';
import 'models/recycling_station.dart';
import 'package:dino_tracker/repositories/station_repository.dart';
import 'screens/recycling_record_screen.dart';
import 'screens/add_record_screen.dart';
import 'screens/record_details_screen.dart';
import 'screens/recycling_statistics_screen.dart';
import 'models/recycling_display_entry.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'service/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatformWeb);
  StationRepository().startListeningForStationApprovals();

  try {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
  } catch (e) {
    debugPrint("Error setting timezone: $e");
  }

  NotificationService notificationService = NotificationService();
  await notificationService.initializeNotifications();

  // Default challenges sync after sign-in (splash screen); reports are
  // settled in the admin panel, so nothing else needs to run here.

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dino Trash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF4CAF50),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFF8BC34A),
          tertiary: const Color(0xFFCDDC39),
          background: const Color(0xFFF5F9F0),
        ),
        fontFamily: 'CuteFont',
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF2E7D32)),
          bodyLarge: TextStyle(color: Color(0xFF333333)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 25),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const SplashScreen(), // Keep your existing splash screen
      routes: {
        '/station_details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as RecyclingStation;
          return StationDetailsScreen(station: args);
        },
        '/recycling_records': (context) => RecyclingRecordsPage(),
        '/add_recycling_record': (context) => AddRecyclingRecordPage(),
        '/recycling_stats': (context) => RecyclingStatsPage(),
        '/recycling_record_detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return RecyclingRecordDetailPage(
            entry: args['entry'] as RecyclingDisplayEntry,
            date: args['date'] as String,
          );
        },
      },
    );
  }
}