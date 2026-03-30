import 'package:flutter/material.dart';
import '../theme.dart';

class StatsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("TABLEAU DE BORD", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Résumé du mois", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),

            // Grille de petites cartes
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.5,
              children: [
                _buildStatMiniCard("Vues", "1.2k", Icons.visibility, Colors.blue),
                _buildStatMiniCard("Itinéraires", "450", Icons.directions, Colors.orange),
                _buildStatMiniCard("Appels", "89", Icons.phone, PharmaTheme.emeraldGreen),
                _buildStatMiniCard("Favoris", "12", Icons.favorite, Colors.red),
              ],
            ),

            SizedBox(height: 30),

            // Carte pour le Graphique
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Activité hebdomadaire", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 20),
                  Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[100], // Remplace par un LineChart de fl_chart
                    child: Center(child: Text("Graphique ici", style: TextStyle(color: Colors.grey))),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            // Section "Conseils IA" (Très 2026 !)
            _buildAiInsightCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMiniCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAiInsightCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [PharmaTheme.emeraldGreen, Color(0xFF004D40)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: 30),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              "Conseil : Vos visites augmentent le samedi soir. Activez la mise en avant 'Garde' pour booster vos ventes.",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}