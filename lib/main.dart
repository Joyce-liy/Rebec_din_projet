import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ AJOUTÉ
import 'package:pharma/firebase_options.dart' as options;
import 'package:pharma/home_screen.dart';
import 'package:pharma/pageconnection/login_screen.dart';
import 'package:pharma/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // ✅ ORDRE CRITIQUE
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 1. CHARGER .env EN PREMIER (AVANT FIREBASE)
  try {
    await dotenv.load(fileName: ".env");
    print("✅ Fichier .env chargé avec succès");

    // Vérification que la clé existe
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      print("❌ ERREUR : GEMINI_API_KEY non trouvée dans .env");
    } else {
      print("✅ Clé API trouvée : ${key.substring(0, 10)}...");
    }
  } catch (e) {
    print("❌ ERREUR chargement .env : $e");
  }

  // ✅ 2. PUIS Firebase
  await Firebase.initializeApp(
    options: options.DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ 3. DÉTERMINER L'ÉCRAN DE DÉPART
  // Le splash + onboarding ne doivent apparaître que lors de la toute
  // première ouverture de l'app (avant la création d'un compte).
  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
  final currentUser = FirebaseAuth.instance.currentUser;

  Widget initialScreen;
  if (currentUser != null) {
    // Déjà connecté : on va directement à l'accueil, pas de splash.
    initialScreen = HomeScreen(userName: currentUser.displayName ?? "Joyce");
  } else if (!seenOnboarding) {
    // Toute première installation : splash puis onboarding.
    initialScreen = const SplashScreen();
  } else {
    // Onboarding déjà vu mais plus connecté (déconnexion) : pas de splash.
    initialScreen = const LoginScreen();
  }

  // ✅ 4. ENFIN lancer l'app
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: initialScreen,
  ));
}

// Vous pouvez supprimer MyApp et MyHomePage si vous ne les utilisez pas
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharma App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}