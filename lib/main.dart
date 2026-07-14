import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pharm_admin/screens/admin_dashboard_screen.dart';
import 'package:pharm_admin/screens/pricing_screen.dart';
import 'package:pharm_admin/screens/welcome_screen.dart';
import 'package:pharm_admin/screens/pharmacist_hub_screen.dart';
import 'package:pharm_admin/l10n/app_language.dart';
import 'package:pharm_admin/l10n/app_localizations.dart';
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
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.instance,
      builder: (context, locale, child) {
        return MaterialApp(
          title: 'PharmaGeo',
          debugShowCheckedModeBanner: false,
          theme: PharmaTheme.lightTheme,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AuthWrapper(), // Point de départ
        );
      },
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
