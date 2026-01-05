import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pharma/pageconnection/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Initialiser à null pour gérer le chargement
  String? selectedQuartier; 
  bool isFrench = true;
  List<String> quartiers = [];

  @override
  void initState() {
    super.initState();
    loadQuartiers();
  }

  Future<void> loadQuartiers() async {
    try {
      final String response = await rootBundle.loadString('assets/data/quartiers.json');
      final data = await json.decode(response);
      
      setState(() {
        quartiers = List<String>.from(data['yaounde']);
        // Sélectionner le premier quartier par défaut si la liste n'est pas vide
        if (quartiers.isNotEmpty) {
          selectedQuartier = quartiers[0]; 
        }
      });
    } catch (e) {
      print("Erreur lors du chargement du JSON: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFAED5E4),
                    child: Text("J", style: TextStyle(fontSize: 32, color: Colors.black)),
                  ),
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
                ],
              ),
            ),
            const SizedBox(height: 30),

            _buildSectionHeader("Paramètres"),
            
            // Correction ici pour le Dropdown
            _buildSettingRow(
              "Mon Quartier",
              quartiers.isEmpty 
                ? const CircularProgressIndicator.adaptive() // Affiche un loader pendant le chargement
                : DropdownButton<String>(
                    value: selectedQuartier,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: quartiers.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value), // Affiche le nom simple
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        selectedQuartier = newValue;
                      });
                    },
                  ),
            ),
            
            const Divider(height: 1),
            
            _buildSettingRow(
              "Langue",
              Row(
                children: [
                  const Text("Française"),
                  const SizedBox(width: 10),
                  Switch(
                    value: isFrench,
                    onChanged: (val) => setState(() => isFrench = val),
                    activeColor: Colors.blue,
                  ),
                ],
              ),
            ),

            _buildSectionHeader("Aide"),
            _buildSimpleRow("Numéros d’urgence"),
            
            const SizedBox(height: 20),

            // Espace Pharmacien
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell( // Ajout d'une interaction
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3CDE0),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock, color: Colors.black),
                      SizedBox(width: 20),
                      Text("Espace pharmacien", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),

            const Spacer(),

            TextButton(
                onPressed: () {
                  // Remplacer par votre page de Login/Home finale
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
              child: const Text("Déconnecter", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: const Color(0xFFF2F2F2),
      child: Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildSettingRow(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSimpleRow(String title) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: () {},
    );
  }
}