import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pharma/edit.dart'; // Assure-toi que le nom du fichier est correct
import 'package:pharma/pageconnection/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;

  const SettingsScreen({super.key, this.userName = "Joyce"});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String localUserName;
  String? selectedQuartier;
  bool isFrench = true;
  List<String> quartiers = [];

  @override
  void initState() {
    super.initState();
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
      debugPrint("Erreur chargement quartiers: $e");
    }
  }

  Future<void> _navigateToEdit() async {
    final String? newName = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(currentName: localUserName),
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() => localUserName = newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    String initial = localUserName.isNotEmpty ? localUserName[0].toUpperCase() : "J";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8), // Fond doux
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // --- HEADER PROFIL ---
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(25),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        initial,
                        style: TextStyle(fontSize: 28, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(localUserName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const Text("Paramètres du compte", style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                        child: const Icon(Icons.edit_outlined, size: 20, color: Colors.green),
                      ),
                      onPressed: _navigateToEdit,
                    ),
                  ],
                ),
              ),
            ),

            // --- SECTIONS ---
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionLabel("PRÉFÉRENCES"),
                  _buildCard([
                    _buildDropdownRow(
                      icon: Icons.location_on_outlined,
                      title: "Mon Quartier",
                      value: selectedQuartier,
                      items: quartiers,
                      onChanged: (val) => setState(() => selectedQuartier = val),
                    ),
                    const Divider(height: 1),
                    _buildSwitchRow(
                      icon: Icons.language_rounded,
                      title: "Langue Française",
                      value: isFrench,
                      onChanged: (val) => setState(() => isFrench = val),
                    ),
                  ]),
                  
                  const SizedBox(height: 25),
                  
                  _buildSectionLabel("ASSISTANCE"),
                  _buildCard([
                    _buildSimpleRow(Icons.emergency_outlined, "Numéros d’urgence", Colors.orange),
                    const Divider(height: 1),
                    _buildSimpleRow(Icons.help_outline_rounded, "Centre d'aide", Colors.blue),
                  ]),
                  
                  const SizedBox(height: 50),
                  
                  // --- BOUTON DÉCONNEXION ---
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    ),
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    label: const Text("Se déconnecter", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION (DESIGN SYSTÈME) ---

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.1)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDropdownRow({required IconData icon, required String title, required String? value, required List<String> items, required Function(String?) onChanged}) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: items.isEmpty 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: items.map((q) => DropdownMenuItem(value: q, child: Text(q, style: const TextStyle(fontSize: 14)))).toList(),
              onChanged: onChanged,
            ),
    );
  }

  Widget _buildSwitchRow({required IconData icon, required String title, required bool value, required Function(bool) onChanged}) {
    return ListTile(
      leading: Icon(icon, color: Colors.green),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Switch.adaptive(
        value: value,
        activeColor: Colors.green,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSimpleRow(IconData icon, String title, Color iconColor) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: () {},
    );
  }
}