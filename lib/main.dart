import 'package:flutter/material.dart';
import 'package:pharm_admin/screens/admin_dashboard_screen.dart';
import 'package:pharm_admin/screens/pricing_screen.dart';
import 'package:pharm_admin/screens/welcome_screen.dart';
import 'theme.dart';
import 'screens/register_screen.dart';


void main() => runApp(PharmacyApp());

class PharmacyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaGeo',
      debugShowCheckedModeBanner: false,
      theme: PharmaTheme.lightTheme,
      home: WelcomeScreen(),// Point de départ
    );
  }
}