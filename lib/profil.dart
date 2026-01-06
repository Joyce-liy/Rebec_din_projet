import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pharma/edit.dart';
import 'package:pharma/pageconnection/login_screen.dart';


class SettingsScreen extends StatefulWidget {
  final String userName;

  const SettingsScreen({super.key, this.userName = "Joyce"});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Variable locale pour gérer la mise à jour dynamique du nom
  late String localUserName;
  String? selectedQuartier; 
  bool isFrench = true;
  List<String> quartiers = [];

  @override
  void initState() {
    super.initState();
    // On initialise le nom local avec le nom reçu du Home
    localUserName = widget.userName;
    loadQuartiers();
  }

  Future<void> loadQuartiers() async {
    try {
      final String response = await rootBundle.loadString('assets/quartiers.json');
      final data = await json.decode(response);
      setState(() {
        quartiers = List<String>.from(data['yaounde']);
        if (quartiers.isNotEmpty) selectedQuartier = quartiers[0]; 
      });
    } catch (e) {
      debugPrint("Erreur JSON: $e");
    }
  }

  // MÉTHODE DE NAVIGATION VERS L'ÉDITION
  Future<void> _navigateToEdit() async {
    // On attend le résultat (le nouveau nom) de la page EditProfileScreen
    final String? newName = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(currentName: localUserName),
      ),
    );

    // Si un nouveau nom a été saisi, on met à jour l'interface
    if (newName != null && newName.isNotEmpty) {
      setState(() {
        localUserName = newName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcul de l'initiale basé sur le nom LOCAL
    String initial = localUserName.isNotEmpty 
        ? localUserName[0].toUpperCase() 
        : "J";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFFE8F5E9),
                    child: Text(
                      initial, // L'initiale change si localUserName change
                      style: const TextStyle(
                        fontSize: 32, 
                        color: Colors.green, 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                  // BOUTON ÉDITER
                  IconButton(
                    icon: const Icon(Icons.edit_outlined), 
                    onPressed: _navigateToEdit, // Appelle la navigation
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            _buildSectionHeader("Paramètres"),
            _buildSettingRow(
              "Mon Quartier",
              quartiers.isEmpty 
                ? const CircularProgressIndicator.adaptive()
                : DropdownButton<String>(
                    value: selectedQuartier,
                    underline: const SizedBox(),
                    items: quartiers.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                    onChanged: (val) => setState(() => selectedQuartier = val),
                  ),
            ),
            
            _buildSettingRow(
              "Langue",
              Switch(
                value: isFrench,
                onChanged: (val) => setState(() => isFrench = val),
                activeColor: Colors.green,
              ),
            ),

            _buildSectionHeader("Aide"),
            _buildSimpleRow("Numéros d’urgence"),
            
            const Spacer(),

            TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
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
        children: [Text(title, style: const TextStyle(fontSize: 16)), trailing],
      ),
    );
  }

  Widget _buildSimpleRow(String title) {
    return ListTile(title: Text(title), contentPadding: const EdgeInsets.symmetric(horizontal: 20), onTap: () {});
  }
}