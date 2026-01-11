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
      const Center(child: Text('Map Page')),      
      const Center(child: Text('Scanner Page')),   
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
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: "Map"),
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
  late Future<List<String>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  // MÉTHODE CORRIGÉE : On récupère .value du ValueNotifier
  Future<List<String>> _loadHistory() async {
    await HistoryService.instance.load();
    // history est un ValueNotifier, donc on retourne sa .value
    return HistoryService.instance.history.value; 
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _historyFuture = _loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    String initial = widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "J";

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // En-tête
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
              // Filtres (Chips)
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

              // Liste dynamique
             // Remplacez le bloc FutureBuilder par celui-ci dans home_screen.dart
ValueListenableBuilder<List<String>>(
  valueListenable: HistoryService.instance.history,
  builder: (context, historyList, child) {
    // On applique le filtre si nécessaire
    final filtered = historyList
        .where((_) => _selectedFilter == "All" || _selectedFilter == "Recherche")
        .toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("Aucun historique disponible", style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // On affiche l'historique mis à jour en temps réel
    return Column(
      children: filtered.reversed
          .map((term) => _buildHistoryItem(Icons.search, term))
          .toList(),
    );
  },
),
              const SizedBox(height: 20),
            ],
          ),
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