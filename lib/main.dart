import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:pharm_admin/screens/admin_dashboard_screen.dart';
import 'package:pharm_admin/screens/pricing_screen.dart';
import 'package:pharm_admin/screens/welcome_screen.dart';
import 'package:pharm_admin/screens/pharmacist_hub_screen.dart';
import 'theme.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(PharmacyApp());
}

class PharmacyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaGeo',
      debugShowCheckedModeBanner: false,
      theme: PharmaTheme.lightTheme,
      home: AuthWrapper(), // Point de départ
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user != null) {
            return PharmacistHubScreen();
          } else {
            return WelcomeScreen();
          }
        }
        return Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
