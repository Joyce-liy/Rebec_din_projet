
import 'package:flutter/material.dart';
import '../theme.dart';
import 'add_pharmacy_screen.dart';
import 'subscription_screen.dart';
import 'create_ad_screen.dart';

class PharmacistHubScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF4F7F6), // Fond gris-vert très doux
      body: Column(
        children: [
          // --- HEADER : PROFIL & BIENVENUE ---
          _buildHeader(context),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Gestion de l'officine"),
                  SizedBox(height: 15),

                  // GRILLE D'ACTIONS PRINCIPALES
                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.1,
                    children: [
                      _buildActionCard(
                        context,
                        title: "Ma Pharmacie",
                        subtitle: "Localisation GPS",
                        icon: Icons.map_rounded,
                        color: PharmaTheme.emeraldGreen,
                        target: AddPharmacyScreen(),
                      ),
                      _buildActionCard(
                        context,
                        title: "Abonnement",
                        subtitle: "Gérer mon offre",
                        icon: Icons.card_membership_rounded,
                        color: Colors.orangeAccent,
                        target: SubscriptionScreen(),
                      ),
                      _buildActionCard(
                        context,
                        title: "Publicité",
                        subtitle: "Booster ma visibilité",
                        icon: Icons.campaign_rounded,
                        color: Colors.blueAccent,
                        target: CreateAdScreen(),
                      ),
                      _buildActionCard(
                        context,
                        title: "Statistiques",
                        subtitle: "Vues et clics",
                        icon: Icons.bar_chart_rounded,
                        color: Colors.purpleAccent,
                        target: null, // À créer plus tard
                      ),
                    ],
                  ),

                  SizedBox(height: 30),
                  _buildSectionTitle("Assistance & Réglages"),
                  SizedBox(height: 15),

                  // OPTIONS SUPPLÉMENTAIRES (LIGNES)
                  _buildOptionTile(Icons.help_outline, "Centre d'aide", "Contacter le support"),
                  _buildOptionTile(Icons.settings_outlined, "Paramètres", "Compte et sécurité"),

                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET : HEADER PERSONNALISÉ ---
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(25, 60, 25, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PharmaTheme.emeraldGreen, Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(Icons.person, color: Colors.white, size: 35),
          ),
          SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Bonjour,",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                "Dr. Diallo",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Spacer(),
          // Badge de notification
          Stack(
            children: [
              Icon(Icons.notifications_none_rounded, color: Colors.white, size: 30),
              Positioned(
                right: 0,
                child: Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
    );
  }

  // --- WIDGET : CARTE D'ACTION ---
  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, Widget? target}) {
    return GestureDetector(
      onTap: () {
        if (target != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => target));
        }
      },
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // --- WIDGET : TILE D'OPTION ---
  Widget _buildOptionTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey),
          SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          Spacer(),
          Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}