//le pharmacien choisi son forfait

import 'package:flutter/material.dart';
import '../theme.dart';

class PricingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Boostez votre Pharmacie")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Choisissez un plan pour apparaître en tête des recherches",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: PharmaTheme.darkGrey),
            ),
            SizedBox(height: 30),

            // Carte Plan Gratuit
            _buildPricingCard(
              context,
              title: "Plan Standard",
              price: "Gratuit",
              features: ["Visibilité sur la carte", "Infos de contact"],
              isPopular: false,
            ),

            SizedBox(height: 20),

            // Carte Plan Premium (Prioritaire)
            _buildPricingCard(
              context,
              title: "Plan Premium",
              price: "15 000 FCFA /mois",
              features: [
                "Position prioritaire (Top liste)",
                "Badge 'Vérifié' Émeraude",
                "Publicité sur l'écran d'accueil",
                "Statistiques de visite"
              ],
              isPopular: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard(BuildContext context, {required String title, required String price, required List<String> features, required bool isPopular}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isPopular ? PharmaTheme.emeraldGreen : Colors.grey.shade300,
          width: isPopular ? 3 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          if (isPopular)
            Chip(label: Text("RECOMMANDÉ"), backgroundColor: PharmaTheme.emeraldGreen, labelStyle: TextStyle(color: Colors.white)),
          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text(price, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: PharmaTheme.emeraldGreen)),
          Divider(height: 30),
          ...features.map((f) => Padding(
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [Icon(Icons.check_circle, color: PharmaTheme.emeraldGreen, size: 20), SizedBox(width: 10), Text(f)]),
          )).toList(),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () { /* Logique de paiement future */ },
            style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 45)),
            child: Text("Sélectionner"),
          )
        ],
      ),
    );
  }
}