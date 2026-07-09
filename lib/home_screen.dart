import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pharma/search_screen.dart';
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

class _P {
  static const primary       = Color(0xFF2563EB);  // Bleu médical profond
  static const primaryLight  = Color(0xFF3B82F6);  // Bleu moyen
  static const primarySurf   = Color(0xFFEFF6FF);  // Bleu très clair
  static const accent        = Color(0xFF10B981);  // Vert émeraude — disponibilité
  static const accentSurf    = Color(0xFFD1FAE5);  // Vert très clair
  static const warning       = Color(0xFFF59E0B);  // Ambre
  static const warningSurf   = Color(0xFFFEF3C7);
  static const danger        = Color(0xFFEF4444);  // Corail
  static const dangerSurf    = Color(0xFFFEE2E2);
  static const neutral       = Color(0xFF64748B);
  static const neutralSurf   = Color(0xFFF1F5F9);
  static const surface       = Color(0xFFF8FAFD);  // Blanc chaud
  static const cardBg        = Color(0xFFFFFFFF);
  static const textH1        = Color(0xFF0D1B2A);  // Bleu nuit profond
  static const textBody      = Color(0xFF4A5568);  // Ardoise chaud
  static const textMuted     = Color(0xFF94A3B8);
  static const border        = Color(0xFFE2E8F0);  // Gris perle chaud
}

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, this.userName = "Joyce"});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  double _buttonX = 20.0;
  double _buttonY = 100.0;
  bool _isFirstLoad = true;
  List<String>? _cadnetMedications;

  @override
  Widget build(BuildContext context) {
    if (_isFirstLoad) {
      _buttonX = MediaQuery.of(context).size.width - 80;
      _buttonY = MediaQuery.of(context).size.height - 230;
      _isFirstLoad = false;
    }

    final pages = [
      HomeBody(
        userName: widget.userName,
        onSearchTap: () => setState(() => _currentIndex = 1),
        onScanTap: () async {
          final result = await Navigator.push<List<String>>(
            context,
            MaterialPageRoute(builder: (_) => const ScannerPage()),
          );
          if (result != null && result.isNotEmpty) {
            setState(() {
              _cadnetMedications = List<String>.from(result);
              _currentIndex = 1;
            });
          }
        },
      ),
      SearchScreen(
        onSearchFocusChanged: (bool isFocused) {},
        scannedMedications: _cadnetMedications,
      ),
      SettingsScreen(userName: widget.userName),
    ];

    return Scaffold(
      backgroundColor: _P.surface,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex == 3 ? 2 : _currentIndex,
            children: pages,
          ),
          // ── FAB IA déplaçable
          if (_currentIndex == 0 || _currentIndex == 1)
            Positioned(
              left: _buttonX,
              top: _buttonY,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    _buttonX += d.delta.dx;
                    _buttonY += d.delta.dy;
                  });
                },
                child: _AiFab(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatAIScreen()),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildNavbar(),
    );
  }

  Widget _buildNavbar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: _P.cardBg.withOpacity(0.88),
            border: Border(
              top: BorderSide(color: _P.border, width: 1),
            ),
          ),
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  index: 0,
                  current: _currentIndex,
                  icon: Icons.home_rounded,
                  label: 'Accueil',
                  onTap: (_) => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  index: 1,
                  current: _currentIndex,
                  icon: Icons.search_rounded,
                  label: 'Recherche',
                  onTap: (_) => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  index: 2,
                  current: _currentIndex,
                  icon: Icons.document_scanner_rounded,
                  label: 'Cadnet',
                  onTap: (_) async {
                    final result = await Navigator.push<List<String>>(
                      context,
                      MaterialPageRoute(builder: (_) => const ScannerPage()),
                    );
                    if (result != null && result.isNotEmpty) {
                      setState(() {
                        _cadnetMedications = List<String>.from(result);
                        _currentIndex = 1;
                      });
                    }
                  },
                ),
                _NavItem(
                  index: 3,
                  current: _currentIndex,
                  icon: Icons.person_rounded,
                  label: 'Profil',
                  onTap: (_) => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// NAV ITEM
// ─────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final int index;
  final int current;
  final IconData icon;
  final String label;
  final void Function(int) onTap;

  const _NavItem({
    required this.index,
    required this.current,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? _P.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? _P.primary : _P.textMuted,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _P.primary : _P.textMuted,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FAB IA — avec pulsation douce (scale 1.0 → 1.08, 1800ms)
// ─────────────────────────────────────────────────────────────
class _AiFab extends StatefulWidget {
  final VoidCallback onTap;
  const _AiFab({required this.onTap});

  @override
  State<_AiFab> createState() => _AiFabState();
}

class _AiFabState extends State<_AiFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: _pulseAnim.value,
          child: child,
        ),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_P.primary, _P.accent],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _P.primary.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: _P.accent.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HOME BODY
// ─────────────────────────────────────────────────────────────
class HomeBody extends StatefulWidget {
  final String userName;
  final VoidCallback? onSearchTap;
  final VoidCallback? onScanTap;
  const HomeBody({
    super.key,
    required this.userName,
    this.onSearchTap,
    this.onScanTap,
  });

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  String _selectedFilter = 'All';

  // ── Carrousel
  late final PageController _bannerController;
  late final Timer _bannerTimer;
  int _bannerIndex = 0;

  static const _bannerImages = [
    'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&q=80',
    'https://images.unsplash.com/photo-1628771065518-0d82f1938462?w=800&q=80',
    'https://images.unsplash.com/photo-1559757148-5c350d0d3c56?w=800&q=80',
    'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=800&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _bannerController = PageController();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _bannerIndex = (_bannerIndex + 1) % _bannerImages.length;
      _bannerController.animateToPage(
        _bannerIndex,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _bannerTimer.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    await HistoryService.instance.load();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'J';

    return Scaffold(
      backgroundColor: _P.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App bar sticky
            SliverAppBar(
              backgroundColor: _P.surface,
              surfaceTintColor: Colors.transparent,
              floating: true,
              snap: true,
              elevation: 0,
              titleSpacing: 20,
              title: _buildTopBar(initial),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Hero banner
                  _buildHeroBanner(),
                  const SizedBox(height: 16),

                  // ── Pharmacies proches card
                  _buildNearbyCard(),
                  const SizedBox(height: 28),

                  // ── Filtre chips
                  _buildFilterSection(),
                  const SizedBox(height: 24),

                  // ── Historique
                  _buildHistorySection(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar: greeting + avatar
  Widget _buildTopBar(String initial) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour,',
                style: TextStyle(
                  fontSize: 13,
                  color: _P.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                widget.userName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _P.textH1,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _showLogoutDialog(context),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_P.primary, _P.accent],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _P.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : 'J',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Hero banner avec carrousel d'images en arrière-plan
  Widget _buildHeroBanner() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _P.primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Carrousel d'images réseau
            PageView.builder(
              controller: _bannerController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bannerImages.length,
              itemBuilder: (_, i) => Image.network(
                _bannerImages[i],
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: _P.primary,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                errorBuilder: (_, __, ___) => Container(color: _P.primary),
              ),
            ),

            // ── Overlay gradient pour lisibilité du texte
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    _P.primary.withOpacity(0.90),
                    _P.primary.withOpacity(0.55),
                    Colors.black.withOpacity(0.15),
                  ],
                ),
              ),
            ),

            // ── Contenu texte + dots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Texte + badges
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Disponibilité en temps réel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Besoin d\'un\nmédicament ?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Scannez ou tapez le nom.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          _HeroBadge(
                            icon: Icons.search_rounded,
                            label: 'Rechercher',
                            onTap: widget.onSearchTap ?? () {},
                          ),
                          const SizedBox(width: 10),
                          _HeroBadge(
                            icon: Icons.document_scanner_rounded,
                            label: 'Scanner',
                            onTap: widget.onScanTap ?? () {},
                          ),
                        ]),
                      ],
                    ),
                  ),

                  // ── Indicateurs verticaux (dots)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _bannerImages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        width: 6,
                        height: _bannerIndex == i ? 22 : 6,
                        decoration: BoxDecoration(
                          color: _bannerIndex == i
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nearby pharmacies card
  Widget _buildNearbyCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NearbyPharmaciesScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _P.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _P.warning.withOpacity(0.15),
                  _P.warning.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.location_on_rounded,
                color: _P.warning, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pharmacies proches',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _P.textH1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Voir les 5 plus proches de vous',
                  style: TextStyle(fontSize: 12, color: _P.textBody),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _P.warningSurf,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chevron_right_rounded,
                color: _P.warning, size: 20),
          ),
        ]),
      ),
    );
  }

  // ── Filter chips section
  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Filtrer par',
          trailing: const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FilterChip(
              label: 'Tout',
              icon: Icons.apps_rounded,
              selected: _selectedFilter == 'All',
              onTap: () => setState(() => _selectedFilter = 'All'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Recherche',
              icon: Icons.search_rounded,
              selected: _selectedFilter == 'Recherche',
              onTap: () => setState(() => _selectedFilter = 'Recherche'),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Cadnet',
              icon: Icons.folder_copy_rounded,
              selected: _selectedFilter == 'Cadnet',
              onTap: () => setState(() => _selectedFilter = 'Cadnet'),
            ),
          ]),
        ),
      ],
    );
  }

  // ── History section
  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: _selectedFilter == 'All'
              ? 'Historique'
              : 'Résultats $_selectedFilter',
          trailing: GestureDetector(
            onTap: () async {
              await HistoryService.instance.clear();
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _P.dangerSurf,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Effacer',
                style: TextStyle(
                  fontSize: 12,
                  color: _P.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder<List<String>>(
          valueListenable: HistoryService.instance.history,
          builder: (context, historyList, _) {
            final filtered = historyList
                .where((item) =>
                    _selectedFilter == 'All' ||
                    item.startsWith(_selectedFilter))
                .toList();

            if (filtered.isEmpty) {
              return _buildEmptyHistory();
            }

            return Column(
              children: filtered.map((item) {
                final parts = item.split(':');
                final source =
                    parts.isNotEmpty ? parts.first : 'Recherche';
                final term = parts.length > 1
                    ? parts.sublist(1).join(':')
                    : item;
                return _HistoryTile(
                  term: term,
                  source: source,
                  isScan: source == 'Cadnet',
                  onRemove: () => HistoryService.instance.remove(item),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: _P.neutralSurf,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded,
                size: 36, color: _P.textMuted),
          ),
          const SizedBox(height: 14),
          const Text(
            'Historique vide',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: _P.textH1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Vos recherches apparaîtront ici',
            style: TextStyle(fontSize: 13, color: _P.textBody),
          ),
        ]),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _P.dangerSurf,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    color: _P.danger, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Déconnexion ?',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _P.textH1),
              ),
              const SizedBox(height: 8),
              const Text(
                'Voulez-vous vous déconnecter de Pharma ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _P.textBody),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: _P.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(
                            color: _P.textBody,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        final prefs =
                            await SharedPreferences.getInstance();
                        await prefs.clear();
                        await FirebaseAuth.instance.signOut();
                        await GoogleSignIn().signOut();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                      } catch (e) {
                        debugPrint('Erreur: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _P.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Quitter',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMPOSANTS HELPER
// ─────────────────────────────────────────────────────────────

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HeroBadge(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12),
          ),
        ]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _P.primary : _P.cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? _P.primary : _P.border,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _P.primary.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 16, color: selected ? Colors.white : _P.primary),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _P.textBody,
            ),
          ),
        ]),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget trailing;
  const _SectionTitle({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_P.primary, _P.accent],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _P.textH1,
          letterSpacing: -0.3,
        ),
      ),
      const Spacer(),
      trailing,
    ]);
  }
}

class _HistoryTile extends StatelessWidget {
  final String term;
  final String source;
  final bool isScan;
  final VoidCallback onRemove;
  const _HistoryTile(
      {required this.term,
      required this.source,
      required this.isScan,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _P.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isScan ? _P.primarySurf : _P.neutralSurf,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isScan
                ? Icons.document_scanner_rounded
                : Icons.history_rounded,
            size: 18,
            color: isScan ? _P.primary : _P.neutral,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                term,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _P.textH1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Via $source',
                style: const TextStyle(
                    fontSize: 11, color: _P.textMuted),
              ),
            ],
          ),
        ),
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _P.primarySurf,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: _P.primary),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _P.neutralSurf,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close,
                  size: 12, color: _P.textMuted),
            ),
          ),
        ]),
      ]),
    );
  }
}