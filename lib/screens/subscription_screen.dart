import 'package:flutter/material.dart';
import '../theme.dart';

class SubscriptionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER COMPACT & DESIGN ---
            Stack(
              children: [
                // Fond avec courbe réduite
                Container(
                  height: 220, // Taille réduite (au lieu de 300)
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [PharmaTheme.emeraldGreen, Color(0xFF004D40)],
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(MediaQuery.of(context).size.width, 40)),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      // AppBar intégrée au header
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                "ABONNEMENTS",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 14),
                              ),
                            ),
                            SizedBox(width: 48), // Équilibre
                          ],
                        ),
                      ),
                      // Texte condensé
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        child: Column(
                          children: [
                            Text(
                              "Boostez votre visibilité",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            /*SizedBox(height: 6),
                            Text(
                              "Attirez plus de clients vers votre officine dès maintenant.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                            ),*/
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // --- LISTE DES PLANS (Remonte un peu sur le header) ---
            Transform.translate(
              offset: Offset(0, -20), // Fait remonter légèrement la première carte pour un effet design
              child: Padding(
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
                    SizedBox(height: 16),
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
                    SizedBox(height: 16),
                    _buildPlanCard(
                      context,
                      title: "ACCÈS VIP GOLD",
                      price: "40.000",
                      currency: "FCFA /mois",
                      icon: Icons.diamond_outlined,
                      features: ["Haut de liste garanti", "Badge vérifié", "API de stock"],
                      isPopular: false,
                      color: Color(0xFFBF9B30),
                    ),
                    SizedBox(height: 30), // Espace en bas
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Le widget _buildPlanCard reste le même que précédemment pour garder la cohérence
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
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Text("LE PLUS CHOISI", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                            Text(currency, style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
                SizedBox(height: 15),
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: PharmaTheme.emeraldGreen, size: 18),
                      SizedBox(width: 8),
                      Text(f, style: TextStyle(color: Colors.blueGrey[700], fontSize: 13)),
                    ],
                  ),
                )).toList(),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withOpacity(0.85)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text("CHOISIR CE PACK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}