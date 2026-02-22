import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pharma/firebase_options.dart' as options;
import 'package:pharma/splash_screen.dart';
import 'package:pharma/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp();
  options.DefaultFirebaseOptions.currentPlatform;
  
  runApp(const PharmConnectApp());
}

class PharmConnectApp extends StatelessWidget {
  const PharmConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Configure Google Fonts to use Outfit as the default font family
    final textTheme = GoogleFonts.outfitTextTheme(
      Theme.of(context).textTheme,
    );

    return MaterialApp(
      title: 'PharmConnect',
      debugShowCheckedModeBanner: false,
      
      // Apply the premium theme with Google Fonts
      theme: AppTheme.lightTheme.copyWith(
        textTheme: textTheme.apply(
          bodyColor: AppColors.slate700,
          displayColor: AppColors.slate900,
        ),
        primaryTextTheme: textTheme.apply(
          bodyColor: AppColors.slate700,
          displayColor: AppColors.slate900,
        ),
      ),
      
      // Home screen
      home: const SplashScreen(),
      
      // Page transitions
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}
