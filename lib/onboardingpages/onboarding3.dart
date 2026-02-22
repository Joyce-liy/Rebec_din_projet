import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:pharma/pageconnection/login_screen.dart';
// Importez votre fichier de design system ici
 import 'package:pharma/theme/app_theme.dart'; 

class Onboarding3 extends StatelessWidget {
  const Onboarding3({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Utilisation de la couleur de fond du système
      body: SafeArea(
        child: Column(
          children: [
            // Bouton "Passer" stylisé
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TextButton(
                  onPressed: () => _navigateToLogin(context),
                  child: Text(
                    "passer", 
                    style: AppTypography.labelMedium.copyWith(color: AppColors.slate400), 
                  ),
                ),
              ),
            ),
            
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animation Lottie dans un conteneur avec ombre douce
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.medium, // Ombre du design system
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Lottie.asset(
                      'assets/Qr Code Scanner.json',
                      height: 220,
                      repeat: true,
                      animate: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.huge),
                  
                  // Titre avec typographie premium
                  Text(
                    "Scannez et trouvez",
                    textAlign: TextAlign.center,
                    style: AppTypography.displaySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Description avec typographie corps de texte
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                    child: Text(
                      "Prenez votre ordonnance en photo ou tapez le nom du médicament. On s’occupe du reste.",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.slate600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bouton "C'est parti !" utilisant le GradientButton premium
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: GradientButton(
                text: "C'est parti !",
                icon: Icons.arrow_forward_rounded,
                onPressed: () => _navigateToLogin(context),
              ),
            ),
            const SizedBox(height: AppSpacing.massive),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen(userName: '',)),
    );
  }
}