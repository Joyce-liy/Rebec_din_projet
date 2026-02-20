import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ AJOUTÉ
import 'package:pharma/firebase_options.dart' as options;
import 'package:pharma/splash_screen.dart';

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
  
  // ✅ 3. ENFIN lancer l'app
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
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