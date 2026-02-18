import 'package:flutter/material.dart';
import '../theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA), // Un gris très clair pour faire ressortir le blanc
      body: CustomScrollView(
        slivers: [
          // AppBar Moderne avec design arrondi
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            backgroundColor: PharmaTheme.emeraldGreen,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 20, bottom: 16),
              title: Text("Dashboard Pro",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Statistiques Flash",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PharmaTheme.darkGrey)),
                  SizedBox(height: 15),

                  // Grille de stats moderne
                  Row(
                    children: [
                      _buildModernStatCard("Revenus", "1.2M", Icons.auto_graph, Colors.blue),
                      SizedBox(width: 15),
                      _buildModernStatCard("Premium", "45", Icons.star_rounded, Colors.orange),
                    ],
                  ),
                  SizedBox(height: 25),

                  Text("Actions Urgentes",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PharmaTheme.darkGrey)),
                  SizedBox(height: 15),

                  // Liste de demandes stylisée
                  _buildActionCard("Pharmacie Akwa", "En attente de validation", "2 min ago"),
                  _buildActionCard("Pharmacie du Rail", "Paiement à vérifier", "15 min ago"),
                  _buildActionCard("Pharma Plus", "Nouvelle inscription", "1 heure ago"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour les cartes de stats modernes
  Widget _buildModernStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(height: 15),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // Widget pour les lignes d'actions
  Widget _buildActionCard(String name, String status, String time) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: PharmaTheme.emeraldGreen.withOpacity(0.1),
              child: Icon(Icons.storefront, color: PharmaTheme.emeraldGreen)),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(status, style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Text(time, style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
        ],
      ),
    );
  }
}