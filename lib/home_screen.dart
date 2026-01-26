import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pharma/pageconnection/login_screen.dart'; 
import 'package:pharma/profil.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pharma/search_screen.dart';
import 'package:pharma/services/history_service.dart';
import 'package:pharma/scanner_page.dart'; 
import 'package:pharma/chat_ai_screen.dart'; 
// Importez votre page de création ici
import 'package:pharma/create_pharma_screen.dart'; 
import 'package:pharma/nearby_pharmacies_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, this.userName = "Joyce"});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Les pages de la barre de navigation
    final List<Widget> _pages = [
      HomeBody(userName: widget.userName),        
      SearchScreen(onSearchFocusChanged: (bool isFocused) {  },),                                
      const ScannerPage(), 
      SettingsScreen(userName: widget.userName),  
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      extendBody: true, 
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // --- BOUTONS FLOTTANTS CONDITIONNELS (ACCUEIL & RECHERCHE UNIQUEMENT) ---
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1) 
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
             // Bouton 1 (Haut) : Chat IA
              FloatingActionButton(
                heroTag: "btn_chat_ai",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatAIScreen()),
                  );
                },
                backgroundColor: Colors.green.shade700,
                elevation: 6,
                shape: const CircleBorder(),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
              ),

              const SizedBox(height: 12), // Espace entre les deux

              // Bouton 2 (Bas) : Créer une Pharmacie
              Padding(
                padding: const EdgeInsets.only(bottom: 90), // Évite la BottomNavbar
                child: FloatingActionButton(
                  heroTag: "btn_add_pharma",
                  onPressed: () {
                    print("Ouvrir création pharmacie");
                     Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePharmaScreen()));
                  },
                  backgroundColor: Colors.green.shade700,
                  elevation: 4,
                  mini: true, // Plus petit pour garder la hiérarchie
                  child: const Icon(Icons.add_business_rounded, color: Colors.white),
                ),
              ),
            ],
          )
        : null,

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildProfessionalNavbar(),
    );
  }

  Widget _buildProfessionalNavbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 85,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navbarItem(0, Icons.home_rounded, "Accueil"),
                _navbarItem(1, Icons.search_rounded, "Recherche"),
                _navbarItem(2, Icons.document_scanner_rounded, "Scanner"),
                _navbarItem(3, Icons.person_rounded, "Profil"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navbarItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    Color color = isSelected ? Colors.green.shade700 : Colors.grey.shade400;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeBody extends StatefulWidget {
  final String userName;
  const HomeBody({super.key, required this.userName});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  String _selectedFilter = "All";

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final GoogleSignIn googleSignIn = GoogleSignIn();
    await prefs.clear();
    try { await googleSignIn.signOut(); } catch (e) { debugPrint(e.toString()); }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    String initial = widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "J";

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Bonjour,", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                      Text(widget.userName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showLogoutDialog(context),
                  child: CircleAvatar(
                    backgroundColor: Colors.green.shade600,
                    radius: 26,
                    child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildSearchPrompt(),
            const SizedBox(height: 30),
            const Text("Filtrer par", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip("All", Icons.apps_rounded),
                  const SizedBox(width: 12),
                  _buildChip("Recherche", Icons.search_rounded),
                  const SizedBox(width: 12),
                  _buildChip("Scanner", Icons.qr_code_scanner_rounded),
                ],
              ),
            ),
            const SizedBox(height: 35),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_selectedFilter == "All" ? "Historique" : "Résultats $_selectedFilter",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => HistoryService.instance.clear(),
                  child: const Text("Effacer", style: TextStyle(color: Colors.redAccent)),
                )
              ],
            ),
            ValueListenableBuilder<List<String>>(
              valueListenable: HistoryService.instance.history,
              builder: (context, historyList, child) {
                final filtered = historyList.where((item) => _selectedFilter == "All" || item.startsWith(_selectedFilter)).toList();
                if (filtered.isEmpty) return const Center(child: Text("Vide"));
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildHistoryItem(Icons.history_rounded, filtered[index].split(':').last, filtered[index].split(':').first);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPrompt() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Besoin d'un remède ?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Scannez ou tapez le nom.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.medication_liquid_rounded, size: 40, color: Colors.white54),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NearbyPharmaciesScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.location_on, color: Colors.orange.shade700),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Pharmacies Proches",
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Trouver les 5 plus proches",
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange.shade300),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, IconData icon) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.green.shade700),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(IconData icon, String title, String source) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade100)),
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Via $source"),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ),
    );
  }
void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Déconnexion"),
      content: const Text("Voulez-vous vraiment quitter l'application ?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Annuler"),
        ),
        TextButton(
          onPressed: () async {
            try {
              // 1. Déconnexion Firebase
              await FirebaseAuth.instance.signOut();
              // 2. Déconnexion Google
              await GoogleSignIn().signOut();
              // 3. Nettoyage SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!context.mounted) return;

              // 4. Retour au Login et suppression de l'historique de navigation
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            } catch (e) {
              print("Erreur de déconnexion: $e");
            }
          },
          child: const Text("Oui, quitter", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
}