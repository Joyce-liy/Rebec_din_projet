

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma/profil.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<Medicament> allMedicaments = [];
  List<Medicament> filteredResults = [];
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    loadJsonData();
  }

  Future<void> loadJsonData() async {
    final String response = await rootBundle.loadString('assets/pharmacies_data.json');
    final data = json.decode(response);
    setState(() {
      allMedicaments = (data['medicaments'] as List)
          .map((item) => Medicament.fromJson(item))
          .toList();
    });
  }

  void filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        isSearching = false;
        filteredResults = [];
      } else {
        isSearching = true;
        filteredResults = allMedicaments
            .where((m) => m.nom.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              // ACTION : Navigation vers le profil au clic
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              child: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.person, color: Colors.black),
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text("La Recherche", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            const Text("Bonjour, quel medicament recherchez-vous?", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            
            TextField(
              onChanged: (value) => filterSearch(value),
              decoration: InputDecoration(
                hintText: "Recherche un medicament (ex: Doliprane)",
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                filled: true,
                fillColor: Colors.grey[100], // Légèrement plus grisé pour le contraste
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            Text(
              isSearching ? "Résultats trouvés" : "Historique des recherche recentes",
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 10),
            
            Expanded(
              child: isSearching ? _buildSearchResults() : _buildHistoryList(),
            ),
          ],
        ),
      ),
    );
  }

  // Vos méthodes de construction de listes restent les mêmes...
  Widget _buildSearchResults() {
    if (filteredResults.isEmpty) {
      return const Center(child: Text("Aucun médicament trouvé"));
    }
    return ListView.builder(
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final med = filteredResults[index];
        return ExpansionTile(
          title: Text("${med.nom} (${med.dosage})", 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          subtitle: Text("${med.pharmacies.length} pharmacies disponibles"),
          children: med.pharmacies.map((ph) {
            return ListTile(
              leading: const Icon(Icons.local_pharmacy, color: Colors.redAccent),
              title: Text(ph['nom_pharmacie']),
              subtitle: Text("${ph['quartier']} - ${ph['prix']}"),
              trailing: Text(ph['statut'], style: TextStyle(
                color: ph['statut'] == "En stock" ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold
              )),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    final List<String> recentSearches = ["Doliprane", "Efferalgan", "Nurofen"];
    return ListView.separated(
      itemCount: recentSearches.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(recentSearches[index]),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}

// --- CLASSE MEDICAMENT ---
class Medicament {
  final String nom;
  final String dosage;
  final List<Map<String, dynamic>> pharmacies;

  Medicament({required this.nom, required this.dosage, required this.pharmacies});

  factory Medicament.fromJson(Map<String, dynamic> json) {
    return Medicament(
      nom: json['nom'] ?? '',
      dosage: json['dosage'] ?? '',
      pharmacies: (json['pharmacies'] as List<dynamic>?)
          ?.map((p) => Map<String, dynamic>.from(p as Map))
          .toList() ?? [],
    );
  }
}

// --- PAGE DE PROFIL (À créer/modifier) ---
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mon Profil")),
      body: const Center(child: Text("Bienvenue sur votre profil")),
    );
  }
}