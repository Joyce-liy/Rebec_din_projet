import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? selectedQuartier = "Tsinga, Yaounde";
  bool isFrench = true;
  List<String> quartiers = [];

  @override
  void initState() {
    super.initState();
    loadQuartiers();
  }

  // Chargement des données depuis le fichier JSON
  Future<void> loadQuartiers() async {
    final String response = await rootBundle.loadString('assets/data/quartiers.json');
    final data = await json.decode(response);
    setState(() {
      quartiers = List<String>.from(data['yaounde']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20),
            // Header avec Avatar et bouton Editer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFAED5E4),
                    child: Text("J", style: TextStyle(fontSize: 32, color: Colors.black)),
                  ),
                  IconButton(icon: Icon(Icons.edit_outlined), onPressed: () {}),
                ],
              ),
            ),
            SizedBox(height: 30),

            // Section Paramètres
            _buildSectionHeader("Parametres"),
            _buildSettingRow(
              "Mon Quatier",
              DropdownButton<String>(
                value: selectedQuartier?.split(',')[0],
                underline: SizedBox(),
                icon: Icon(Icons.keyboard_arrow_down),
                items: quartiers.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text("$value, Yaounde"),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() => selectedQuartier = "$newValue, Yaounde");
                },
              ),
            ),
            Divider(height: 1),
            _buildSettingRow(
              "Langue",
              Row(
                children: [
                  Text("Francaise"),
                  SizedBox(width: 10),
                  Switch(
                    value: isFrench,
                    onChanged: (val) => setState(() => isFrench = val),
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ),

            // Section Aide
            _buildSectionHeader("Aide"),
            _buildSimpleRow("Numeros d’urgence"),
            
            SizedBox(height: 20),

            // Espace Pharmacien (Bouton Bleu)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  color: Color(0xFFB3CDE0),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.black),
                    SizedBox(width: 20),
                    Text("Espace pharmacien", style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),

            Spacer(),

            // Bouton Déconnecter
            TextButton(
              onPressed: () {},
              child: Text("Deconnecter", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Widget pour les titres de section grisés
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: Color(0xFFF2F2F2),
      child: Text(title, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
    );
  }

  // Ligne de paramètre avec un widget à droite
  Widget _buildSettingRow(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16)),
          trailing,
        ],
      ),
    );
  }

  // Ligne simple pour l'aide
  Widget _buildSimpleRow(String title) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, style: TextStyle(fontSize: 16)),
      onTap: () {},
    );
  }
}