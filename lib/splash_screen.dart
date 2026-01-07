import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // 1. Import de Lottie
import 'package:pharma/onboardingpages/onboarding1_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // On attend 4 secondes pour laisser l'animation se jouer
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OnboardingScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 2. REMPLACEMENT : Image statique par une animation Lottie
            Lottie.asset(
              'assets/Illustration Search pharmacy unit.json', 
              width: 250,
              repeat: true,
              animate: true,
            ),
            
            const SizedBox(height: 30),
            
            // 3. Texte ou Logo de l'application
            const Text(
              "PHARMA",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
                letterSpacing: 2,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Indicateur de chargement plus discret
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}