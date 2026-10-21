import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:remedi_app/screens/auth_screen.dart';
import 'package:remedi_app/screens/home_screen.dart';
import 'package:remedi_app/screens/splash_screen.dart';
import 'package:remedi_app/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();

  runApp(const RemediApp());
}

class RemediApp extends StatelessWidget {
  const RemediApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
