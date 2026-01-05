import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // 1. Importez le package
import 'package:pharma/onboardingpages/onboarding3.dart';

class Onboarding2 extends StatelessWidget {
  const Onboarding2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Bouton "Passer"
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Onboarding3()),
                  );
                },
                child: const Text(
                  "passer", 
                  style: TextStyle(color: Color(0xFFAED5E4)), 
                ),
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 2. REMPLACEMENT : Lottie au lieu de Image.asset
                    Lottie.asset(
                      'assets/Messaging CharacterAnimation.json', // Votre fichier Lottie
                      height: 280,
                      repeat: true, // L'animation tourne en boucle
                      animate: true,
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      "Stocks verifies en direct",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Notre IA interroge les pharmacies les plus proches de vous par WhatsApp et vous confirme la disponibilite immediatement",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pagination Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildDot(isActive: false),
                buildDot(isActive: true),
                buildDot(isActive: false),
              ],
            ),
            
            const SizedBox(height: 40),

            // Bouton "Suivant"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Onboarding3()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Suivant", 
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget buildDot({required bool isActive}) {
    return Container(
      height: 8,
      width: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.black : Colors.black12,
      ),
    );
  }
}