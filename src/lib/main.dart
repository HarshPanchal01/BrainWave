import 'package:flutter/material.dart';
import 'package:src/utils/constant.dart' as utils;
import 'package:src/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:src/screens/login_page.dart';
import 'package:src/screens/home_screen.dart';
import 'package:src/screens/signup_page.dart';
import 'package:timezone/data/latest.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Notification Service
  await NotificationService().init();
  tz.initializeTimeZones();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://rphcagdsmtmhjyrqfzmi.supabase.co/',
    anonKey:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJwaGNhZ2RzbXRtaGp5cnFmem1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzE1MzY4NzIsImV4cCI6MjA0NzExMjg3Mn0.eeVx9hQOsbebMwMjrI5hjmjK3D6GcKZRsUjGnEcHilI',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client; // Supabase client instance

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Supabase Flutter',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        initialRoute: // Check if the user is authenticated
            utils.client.auth.currentSession != null ? '/home' : '/',
        routes: { // Define the routes
          '/': (context) => const LoginPage(),
          '/signup': (context) => const SignUpPage(),
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomeScreen(),
        });
  }
}