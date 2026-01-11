import 'package:flutter/material.dart';
import 'package:pharma/pageconnection/login_screen.dart'; 
import 'package:pharma/profil.dart'; 
import 'package:pharma/search_screen.dart';
import 'package:pharma/services/history_service.dart';
import 'package:pharma/scanner_page.dart'; 

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
    // Liste des pages de la navigation
    final List<Widget> _pages = [
      HomeBody(userName: widget.userName),        
      const SearchScreen(),                                             
      const ScannerPage(), // Cette page s'affichera quand on clique sur l'index 2 (Scanner)
      SettingsScreen(userName: widget.userName),  
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Accueil"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Recherche"),
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner_outlined), label: "Scanner"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profil"),
        ],
      ),
    );
  }
}

// --- CORPS DE L'ACCUEIL ---

class HomeBody extends StatefulWidget {
  final String userName;
  const HomeBody({super.key, required this.userName});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  String _selectedFilter = "All";

  @override
  Widget build(BuildContext context) {
    String initial = widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "J";

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // En-tête (Hello...)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text("Hello, ${widget.userName}", 
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                ),
                GestureDetector(
                  onTap: () => _showLogoutDialog(context),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFE8F5E9),
                    radius: 25,
                    child: Text(initial, style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 25),
            // FILTRES (All, Recherche, Scanner)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip("All"),
                  const SizedBox(width: 10),
                  _buildChip("Recherche", icon: Icons.search),
                  const SizedBox(width: 10),
                  _buildChip("Scanner", icon: Icons.document_scanner),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              _selectedFilter == "All" ? "Historique récent" : "Historique $_selectedFilter",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            // LISTE DYNAMIQUE FILTRÉE
            ValueListenableBuilder<List<String>>(
              valueListenable: HistoryService.instance.history,
              builder: (context, historyList, child) {
                
                // LOGIQUE DE FILTRE CORRIGÉE
                final filtered = historyList.where((item) {
                  if (_selectedFilter == "All") return true;
                  // On vérifie si l'item commence par la source (Recherche: ou Scanner:)
                  return item.startsWith(_selectedFilter);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("Aucun historique disponible", style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return Column(
                  children: filtered.map((entry) {
                    // On sépare la source du nom pour l'affichage
                    // Exemple: "Scanner:Doliprane" -> parts[0]="Scanner", parts[1]="Doliprane"
                    final parts = entry.split(':');
                    final source = parts[0];
                    final name = parts.length > 1 ? parts[1] : parts[0];
                    
                    IconData itemIcon = (source == "Scanner") 
                        ? Icons.document_scanner 
                        : Icons.search;

                    return _buildHistoryItem(itemIcon, name);
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, {IconData? icon}) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Chip(
        avatar: icon != null ? Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.green) : null,
        label: Text(label),
        backgroundColor: isSelected ? Colors.green : Colors.white,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
        side: const BorderSide(color: Colors.green),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildHistoryItem(IconData icon, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context, MaterialPageRoute(builder: (context) => const LoginScreen()), (r) => false),
            child: const Text("Oui", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}