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

  // Liste pour l'historique (comme sur l'image)
  final List<String> recentSearches = [
    "Doliprane", "Efferalgan", "Nurofen", "Aspégic", "Spasfon", "Gaviscon", "Maalox"
  ];

  @override
  void initState() {
    super.initState();
    loadJsonData();
  }

  Future<void> loadJsonData() async {
    try {
      final String response = await rootBundle.loadString('assets/pharmacies_data.json');
      final data = json.decode(response);
      setState(() {
        allMedicaments = (data['medicaments'] as List)
            .map((item) => Medicament.fromJson(item))
            .toList();
      });
    } catch (e) {
      debugPrint("Erreur chargement JSON: $e");
    }
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
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.black, size: 30),
              onPressed: () {
                  // Remplacer par votre page de Login/Home finale
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView( // Pour éviter les erreurs d'overflow sur petits écrans
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text("La Recherche", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 30),
              const Center(
                child: Text("Bonjour, quel medicament recherchez-vous?", 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 25),
              
              // BARRE DE RECHERCHE + MICRO
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => filterSearch(value),
                      decoration: InputDecoration(
                        hintText: "Recherche un medicament",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, color: Colors.green, size: 30),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.mic, color: Colors.white),
                      onPressed: () {},
                    ),
                  )
                ],
              ),
              
              const SizedBox(height: 30),

              // BOUTON SCANNER ORDONNANCE (Vert Large)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                  label: const Text("Scanner une ordonnance", 
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Text(
                isSearching ? "Résultats trouvés" : "Historique des recherche recentes",
                style: const TextStyle(color: Colors.black87, fontSize: 15),
              ),
              const SizedBox(height: 10),
              
              // Liste des résultats ou Historique
              isSearching ? _buildSearchResults() : _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (filteredResults.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(child: Text("Aucun médicament trouvé")),
      );
    }
    return ListView.builder(
      shrinkWrap: true, // Important à l'intérieur d'une Column
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredResults.length,
      itemBuilder: (context, index) {
        final med = filteredResults[index];
        return ExpansionTile(
          title: Text(med.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
          children: med.pharmacies.map((ph) => ListTile(
            title: Text(ph['nom_pharmacie']),
            subtitle: Text(ph['quartier']),
          )).toList(),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentSearches.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(recentSearches[index], style: const TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
        onTap: () {
          // Action lors du clic sur un élément de l'historique
        },
      ),
    );
  }
}

// --- CLASSE MEDICAMENT ---
class Medicament {
  final String nom;
  final List<Map<String, dynamic>> pharmacies;

  Medicament({required this.nom, required this.pharmacies});

  factory Medicament.fromJson(Map<String, dynamic> json) {
    return Medicament(
      nom: json['nom'] ?? '',
      pharmacies: (json['pharmacies'] as List<dynamic>?)
          ?.map((p) => Map<String, dynamic>.from(p as Map))
          .toList() ?? [],
    );
  }
}