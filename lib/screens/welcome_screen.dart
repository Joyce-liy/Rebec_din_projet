import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'pharmacist_hub_screen.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // Dégradé léger pour ne pas laisser le fond tout blanc
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF1F8E9), // Une touche de vert très pâle en bas
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- L'ANIMATION LOTTIE 3D ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Lottie.asset(
                      'assets/animations/pharm.json', //  fichier 3D
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 20),

                  // --- TITRE & SLOGAN ---
                  Text(
                    "PharmConnect ",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20), // Vert foncé pour le texte
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      " boostez votre visibilité en un clic.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey[600],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- SECTION BASSE (BOUTON) ---
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          );
                        },

                      child: Container(
                        height: 65,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [PharmaTheme.emeraldGreen, Color(0xFF004D40)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: PharmaTheme.emeraldGreen.withOpacity(0.4),
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "ACCÉDER AU HUB",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(width: 15),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Version 1.0.0 • Espace Pharmacien",
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}