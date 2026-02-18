import 'package:flutter/material.dart';
import '../theme.dart';

class CreateAdScreen extends StatefulWidget {
  @override
  _CreateAdScreenState createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends State<CreateAdScreen> {
  final TextEditingController _adTextController = TextEditingController();
  int _selectedDuration = 7; // Durée par défaut : 7 jours

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Lancer une Promotion", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: PharmaTheme.darkGrey,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Aperçu de votre publicité"),
            SizedBox(height: 15),

            // --- CARTE DE PRÉVISUALISATION (LIVE) ---
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [PharmaTheme.emeraldGreen, Color(0xFF00695C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: PharmaTheme.emeraldGreen.withOpacity(0.3), blurRadius: 15, offset: Offset(0, 8))],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(Icons.campaign_rounded, size: 120, color: Colors.white.withOpacity(0.1)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(5)),
                          child: Text("PROMO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(height: 10),
                        Text(
                          _adTextController.text.isEmpty
                              ? "Votre message promotionnel apparaîtra ici..."
                              : _adTextController.text,
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 10),
                        Text("Pharmacie Centrale • À 500m", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),
            _buildSectionTitle("Détails de l'offre"),
            SizedBox(height: 15),

            // CHAMP TEXTE
            TextField(
              controller: _adTextController,
              maxLength: 60,
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Ex: -20% sur les produits bébé !",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.edit, color: PharmaTheme.emeraldGreen),
              ),
            ),

            SizedBox(height: 20),
            _buildSectionTitle("Durée de la campagne"),
            SizedBox(height: 15),

            // SÉLECTEUR DE DURÉE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDurationOption(7, "7 Jours", "5.000 F"),
                _buildDurationOption(15, "15 Jours", "9.000 F"),
                _buildDurationOption(30, "30 Jours", "15.000 F"),
              ],
            ),

            SizedBox(height: 40),

            // BOUTON DE PAIEMENT
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => _showPaymentSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PharmaTheme.emeraldGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: Text("VALIDER ET PAYER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]));
  }

  Widget _buildDurationOption(int days, String label, String price) {
    bool isSelected = _selectedDuration == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDuration = days),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        padding: EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? PharmaTheme.emeraldGreen : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? PharmaTheme.emeraldGreen : Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text(price, style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Mode de Paiement", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.phone_android, color: Colors.orange),
              title: Text("Orange Money / MTN Mobile Money"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.credit_card, color: Colors.blue),
              title: Text("Carte Bancaire"),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}