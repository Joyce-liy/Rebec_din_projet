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
    final List<Widget> _pages = [
      HomeBody(userName: widget.userName),        
      const SearchScreen(),                                             
      const ScannerPage(), 
      SettingsScreen(userName: widget.userName),  
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8), // Fond légèrement teinté pour faire ressortir les cartes
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          elevation: 0,
          backgroundColor: Colors.white,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Accueil"),
            BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: "Recherche"),
            BottomNavigationBarItem(icon: Icon(Icons.document_scanner_rounded), label: "Scanner"),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profil"),
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

  @override
  Widget build(BuildContext context) {
    String initial = widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "J";

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),
            // En-tête amélioré
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Bonjour,", 
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      Text(widget.userName, 
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    ],
                  ),
                ),
                _buildAvatar(initial),
              ],
            ),
            
            const SizedBox(height: 30),
            // Zone de recherche visuelle (incitation)
            _buildSearchPrompt(),

            const SizedBox(height: 30),
            // Section Filtres
            const Text("Filtrer par", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
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
                Text(
                  _selectedFilter == "All" ? "Historique récent" : "Résultats $_selectedFilter",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => HistoryService.instance.clear(),
                  child: const Text("Effacer", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                )
              ],
            ),
            const SizedBox(height: 10),

            // Liste d'historique avec animation de chargement
            ValueListenableBuilder<List<String>>(
              valueListenable: HistoryService.instance.history,
              builder: (context, historyList, child) {
                final filtered = historyList.where((item) {
                  if (_selectedFilter == "All") return true;
                  return item.startsWith(_selectedFilter);
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final parts = entry.split(':');
                    final source = parts[0];
                    final name = parts.length > 1 ? parts[1] : parts[0];
                    
                    IconData itemIcon = (source == "Scanner") 
                        ? Icons.document_scanner_outlined 
                        : Icons.history_rounded;

                    return _buildHistoryItem(itemIcon, name, source);
                  },
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    return GestureDetector(
      onTap: () => _showLogoutDialog(context),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: CircleAvatar(
          backgroundColor: Colors.green.shade600,
          radius: 26,
          child: Text(initial, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildSearchPrompt() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Besoin d'un remède ?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text("Scannez votre ordonnance ou tapez le nom du médicament.", 
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.medication_liquid_rounded, size: 40, color: Colors.white.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    bool isSelected = _selectedFilter == label;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = label),
        child: Chip(
          avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.green.shade700),
          label: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          backgroundColor: isSelected ? Colors.green.shade600 : Colors.white,
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
          elevation: isSelected ? 4 : 0,
          side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.shade200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(IconData icon, String title, String source) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 22, color: Colors.green.shade700),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Text("Via $source", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.history_rounded, size: 60, color: Colors.grey.shade200),
          const SizedBox(height: 10),
          const Text("Aucun historique pour le moment", style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Déconnexion"),
        content: const Text("Êtes-vous sûr de vouloir quitter votre session ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler", style: TextStyle(color: Colors.grey.shade600))),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (context) => const LoginScreen()), (r) => false),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("Déconnexion", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}