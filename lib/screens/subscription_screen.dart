import 'package:flutter/material.dart';
import 'dart:ui'; // Pour l'effet de flou si besoin
import '../theme.dart';

class SubscriptionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: Stack( // Utilisation d'un Stack pour les éléments de design en arrière-plan
        children: [
          // --- ÉLÉMENT DÉCORATIF DISCRET ---
          Positioned(
            top: -70,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    PharmaTheme.emeraldGreen.withOpacity(0.08),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- NAVIGATION ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // --- HEADER AVEC DESIGN AFFIRMÉ ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: PharmaTheme.emeraldGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            "NOS FORFAITS 2026",
                            style: TextStyle(
                              color: PharmaTheme.emeraldGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // TEXTE AVEC GRADIENT (Très moderne)
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [const Color(0xFF1A1A1A), PharmaTheme.emeraldGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            "Choisissez votre\nvisibilité.",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white, // Obligatoire pour le ShaderMask
                              height: 1.1,
                              letterSpacing: -1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // Petite ligne décorative
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: PharmaTheme.emeraldGreen,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        const SizedBox(height: 15),

                        Text(
                          "Propulsez votre pharmacie au sommet des recherches à Yaoundé.",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- LISTE DES PLANS (On garde tes cartes que tu as déjà) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildPlanCard(
                          context,
                          title: "FORFAIT BASIC",
                          price: "Gratuit",
                          icon: Icons.eco_outlined,
                          features: ["Visibilité sur la carte", "Infos de contact"],
                          isPopular: false,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(height: 16),
                        _buildPlanCard(
                          context,
                          title: "PACK PREMIUM",
                          price: "15.000",
                          currency: "FCFA /mois",
                          icon: Icons.auto_graph_rounded,
                          features: ["Priorité de recherche", "Bannière promo", "Statistiques"],
                          isPopular: true,
                          color: PharmaTheme.emeraldGreen,
                        ),
                        const SizedBox(height: 16),
                        _buildPlanCard(
                          context,
                          title: "ACCÈS VIP GOLD",
                          price: "40.000",
                          currency: "FCFA /mois",
                          icon: Icons.diamond_outlined,
                          features: ["Haut de liste garanti", "Badge vérifié", "API de stock"],
                          isPopular: false,
                          color: const Color(0xFFBF9B30),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ton widget _buildPlanCard (Je l'ai légèrement affiné pour coller au nouveau style)
  Widget _buildPlanCard(BuildContext context, {
    required String title,
    required String price,
    String currency = "",
    required IconData icon,
    required List<String> features,
    required bool isPopular,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isPopular ? Border.all(color: color.withOpacity(0.3), width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            if (isPopular)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: color,
                child: const Text(
                  "LE PLUS CHOISI",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12, letterSpacing: 0.5)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(price, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                              Text(currency, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...features.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: PharmaTheme.emeraldGreen, size: 18),
                        const SizedBox(width: 10),
                        Text(f, style: TextStyle(color: Colors.blueGrey[800], fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )).toList(),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPopular ? color : const Color(0xFF263238),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("Choisir ce pack", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}