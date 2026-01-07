import 'package:flutter/material.dart';
import 'package:pharma/pageconnection/login_screen.dart'; 
import 'package:pharma/profil.dart'; 
import 'package:pharma/search_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, this.userName = "Joyce"});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // CORRECTION : On initialise la liste avec exactement 5 pages pour correspondre aux 5 icônes
    _pages = [
      HomeBody(userName: widget.userName),        // Index 0
      const SearchScreen(),                       // Index 1
      const MapPage(),                            // Index 2
      const ScannerPage(),                        // Index 3
      SettingsScreen(userName: widget.userName),  // Index 4 : Ici on passe bien le nom
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Map Page'));
  }
}

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Scanner Page'));
  }
}

// --- Le reste du code (HomeBody, etc.) reste identique ---

class HomeBody extends StatefulWidget {
  final String userName;
  const HomeBody({super.key, required this.userName});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  String _selectedFilter = "All";

  final List<Map<String, dynamic>> _historyData = [
    {"type": "Recherche", "icon": Icons.search, "title": "Paracetamol 500mg"},
    {"type": "Recherche", "icon": Icons.search, "title": "Rephenax 400mg"},
    {"type": "Scanner", "icon": Icons.qr_code_scanner, "title": "Ordonnance du 12/08/2025"},
    {"type": "Scanner", "icon": Icons.qr_code_scanner, "title": "Ordonnance du 01/01/2025"},
  ];

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Déconnexion", textAlign: TextAlign.center),
          content: const Text("Voulez-vous vraiment vous déconnecter ?", textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text("Déconnecter", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String initial = widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : "J";

    List<Map<String, dynamic>> filteredList = _historyData.where((item) {
      if (_selectedFilter == "All") return true;
      return item["type"] == _selectedFilter;
    }).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Hello, ${widget.userName}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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
            Row(
              children: [
                _buildChip("All"),
                const SizedBox(width: 10),
                _buildChip("Recherche", icon: Icons.search),
                const SizedBox(width: 10),
                _buildChip("Scanner", icon: Icons.document_scanner),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              _selectedFilter == "All"
                  ? "Historique des recherche et scans"
                  : _selectedFilter == "Recherche"
                      ? "Historique des recherches"
                      : "Historique des scans",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...filteredList.map((item) => _buildHistoryItem(item["icon"], item["title"])).toList(),
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
        avatar: icon != null ? Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.green) : null,
        label: Text(label),
        backgroundColor: isSelected ? Colors.green : Colors.white,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        side: const BorderSide(color: Colors.green),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildHistoryItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: Colors.black54),
          ),
          const SizedBox(width: 15),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}