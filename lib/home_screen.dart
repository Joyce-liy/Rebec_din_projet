import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // AJOUTÉ
import 'package:google_sign_in/google_sign_in.dart'; // AJOUTÉ
import 'package:pharma/pageconnection/login_screen.dart'; 
import 'package:pharma/profil.dart'; 
import 'package:pharma/search_screen.dart';
import 'package:pharma/services/history_service.dart';
import 'package:pharma/scanner_page.dart'; 
import 'package:pharma/chat_ai_screen.dart'; 

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
      backgroundColor: const Color(0xFFF8FAF8),
      extendBody: true, 
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton(
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
      ),
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

  // --- NOUVELLE FONCTION DE DÉCONNEXION RÉELLE ---
  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final GoogleSignIn googleSignIn = GoogleSignIn();

    // Effacer les SharedPreferences (Nom + statut connexion)
    await prefs.clear();
    
    // Déconnexion Google
    try {
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint("Erreur Google Sign Out: $e");
    }

    // Retour au login
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
            _buildSearchPrompt(),
            const SizedBox(height: 30),
            const Text("Filtrer par", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
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
            ValueListenableBuilder<List<String>>(
              valueListenable: HistoryService.instance.history,
              builder: (context, historyList, child) {
                final filtered = historyList.where((item) {
                  if (_selectedFilter == "All") return true;
                  return item.startsWith(_selectedFilter);
                }).toList();

                if (filtered.isEmpty) return _buildEmptyState();

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
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    return GestureDetector(
      onTap: () => _showLogoutDialog(context),
      child: CircleAvatar(
        backgroundColor: Colors.green.shade600,
        radius: 26,
        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Besoin d'un remède ?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Scannez votre ordonnance ou tapez le nom.", style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.medication_liquid_rounded, size: 40, color: Colors.white54),
        ],
      ),
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
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
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
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade100)),
      child: ListTile(
        leading: Icon(icon, color: Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Via $source"),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Padding(
      padding: EdgeInsets.all(40.0),
      child: Text("Aucun historique", style: TextStyle(color: Colors.grey)),
    ));
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment vous déconnecter de PharmConnect ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(
            onPressed: () => _logout(context), // APPEL DE LA FONCTION MODIFIÉE
            child: const Text("Déconnexion", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}