import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pharma/search_screen.dart';
import 'package:pharma/user_avatar.dart';
import 'package:pharma/user_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pharma/pageconnection/login_screen.dart'; 
import 'package:pharma/profil.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pharma/services/history_service.dart';
import 'package:pharma/scanner_page.dart'; 
import 'package:pharma/chat_ai_screen.dart'; 
import 'package:pharma/nearby_pharmacies_screen.dart';
import 'package:pharma/theme/app_theme.dart'; 

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, this.userName = "Joyce"});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  double _buttonX = 20.0;
  double _buttonY = 100.0;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  Future<void> _initializeUserData() async {
    final userDataService = UserDataService.instance;
    final isFirstLogin = await userDataService.isFirstLogin();
    if (isFirstLogin) {
      await userDataService.initializeNewUser(widget.userName);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstLoad) {
      _buttonX = MediaQuery.of(context).size.width - 80;
      _buttonY = MediaQuery.of(context).size.height - 230;
      _isFirstLoad = false;
    }

    final List<Widget> _pages = [
      HomeBody(userName: widget.userName),
      SearchScreen(onSearchFocusChanged: (bool isFocused) {}),
      SettingsScreen(userName: widget.userName),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex == 3 ? 2 : _currentIndex,
            children: _pages,
          ),

          // --- BOUTON IA MOVABLE ---
          if (_currentIndex == 0 || _currentIndex == 1)
            Positioned(
              left: _buttonX,
              top: _buttonY,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _buttonX += details.delta.dx;
                    _buttonY += details.delta.dy;
                  });
                },
                child: FloatingActionButton(
                  heroTag: "btn_chat_ai",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatAIScreen()),
                    );
                  },
                  backgroundColor: AppColors.primary,
                  elevation: 6,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildProfessionalNavbar(),
    );
  }

  Widget _buildProfessionalNavbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        border: Border(top: BorderSide(color: AppColors.slate200, width: 0.5)),
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
    Color color = isSelected ? AppColors.primary : AppColors.slate400;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScannerPage()),
            );
          } else {
            setState(() => _currentIndex = index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppAnimations.normal,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                borderRadius: AppRadius.xlAll,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: color,
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 180),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Welcome & Avatar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Bonjour,", style: AppTypography.bodyLarge.copyWith(color: AppColors.slate500)),
                      // Utilisation d'un FutureBuilder pour charger le nom actuel
                      FutureBuilder<String?>(
                        future: UserDataService.instance.getUserName(),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? widget.userName, 
                            style: AppTypography.displaySmall,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showLogoutDialog(context),
                  child: Container(
                    decoration: AppDecorations.circleAvatar,
                    child: GlobalUserAvatar(
                      radius: 26, 
                      userName: widget.userName,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            
            _buildSearchPrompt(),
            const SizedBox(height: AppSpacing.xxl),
            
            const SectionHeader(title: "Filtrer par"),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip("All", Icons.apps_rounded),
                  const SizedBox(width: AppSpacing.sm),
                  _buildChip("Recherche", Icons.search_rounded),
                  const SizedBox(width: AppSpacing.sm),
                  _buildChip("Scanner", Icons.qr_code_scanner_rounded),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            
            SectionHeader(
              title: _selectedFilter == "All" ? "Historique" : "Résultats $_selectedFilter",
              actionText: "Effacer",
              onActionTap: () async {
                await UserDataService.instance.clearHistory();
                HistoryService.instance.clear();
                setState(() {}); // Rafraîchir l'UI
              },
            ),
            const SizedBox(height: AppSpacing.md),
            
            FutureBuilder<List<String>>(
              future: UserDataService.instance.getHistory(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final historyList = snapshot.data!;
                final filtered = historyList.where((item) => 
                  _selectedFilter == "All" || item.startsWith(_selectedFilter)
                ).toList();
                
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: Text("Historique vide", style: AppTypography.bodyMedium),
                    ),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _buildHistoryItem(
                      Icons.history_rounded, 
                      filtered[index].split(':').last, 
                      filtered[index].split(':').first
                    );
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
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: AppDecorations.gradientPrimary,
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Besoin d'un remède ?", 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                    Text("Scannez ou tapez le nom.", 
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'Outfit')),
                  ],
                ),
              ),
              Icon(Icons.medication_liquid_rounded, size: 40, color: Colors.white.withOpacity(0.5)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const NearbyPharmaciesScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.warningLight.withOpacity(0.5),
              borderRadius: AppRadius.xlAll,
              border: Border.all(color: AppColors.warning.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                IconContainer(
                  icon: Icons.location_on, 
                  color: AppColors.warning, 
                  size: 44, 
                  iconSize: 22
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Pharmacies Proches", 
                        style: AppTypography.labelLarge.copyWith(color: AppColors.warning.withOpacity(0.9))),
                      Text("Trouver les 5 plus proches", 
                        style: AppTypography.bodySmall.copyWith(color: AppColors.warning.withOpacity(0.8))),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.warning.withOpacity(0.5)),
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
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: AppRadius.mdAll,
          boxShadow: isSelected ? AppShadows.soft : null,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.slate200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.primary),
            const SizedBox(width: 8),
            Text(label, 
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.slate700
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(IconData icon, String title, String source) {
    return PremiumCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconContainer(icon: icon, color: AppColors.primary, size: 40, iconSize: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelLarge),
                Text("Via $source", style: AppTypography.bodySmall),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.slate300),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Options de compte"),
       
       
    // content: const Text("Que souhaitez-vous faire ?"),
        actions: [
          // AJOUT : Bouton pour aller au profil sans quitter le dialogue
         
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("Annuler", style: TextStyle(color: AppColors.slate500))
          ),
          TextButton(
            onPressed: () async {
              try {
                await UserDataService.instance.clearSessionData();
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn().signOut();

                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                print("Erreur de déconnexion: $e");
              }
            },
            child: const Text("Se déconnecter", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}