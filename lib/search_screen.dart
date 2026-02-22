import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma/profil.dart';
import 'package:pharma/chat_ai_screen.dart';
import 'package:pharma/map/medication_map_page.dart';
import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/scanner_page.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pharma/services/history_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:pharma/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pharma/profil.dart';
import 'package:pharma/chat_ai_screen.dart';
import 'package:pharma/map/medication_map_page.dart';
import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/scanner_page.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pharma/services/history_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:pharma/theme/app_theme.dart';


class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required void Function(bool isFocused) onSearchFocusChanged,
  });

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  static const double _radiusMeters = 5000;
  late stt.SpeechToText _speech;
  late AnimationController _animationController;
  Timer? _silenceTimer;
  bool _isListening = false;
  bool _isSearchFocused = false;

  final PharmacyService _pharmacyService = PharmacyService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<MedicationCatalogEntry> _catalog = [];
  List<MedicationCatalogEntry> _filtered = [];
  bool _loadingCatalog = true;
  bool _loadingLocation = true;
  bool _isSearching = false;
  bool _locationUnavailable = false;
  GeoPoint? _userLocation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });

    _loadSearchHistory();
    _initialize();
  }

  Future<void> _loadSearchHistory() async {
    await HistoryService.instance.load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _silenceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      if (_isListening) {
        _stopListening();
      }
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('Statut: $val'),
        onError: (val) => print('Erreur: $val'),
      );

      if (available) {
        setState(() => _isListening = true);
        _startSilenceTimer();

        _speech.listen(
          onResult: (val) {
            setState(() {
              _searchController.text = val.recognizedWords;
              if (val.recognizedWords.trim().isNotEmpty) {
                _isSearching = true;
              }
            });
            _startSilenceTimer();
          },
        );
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    _speech.stop();
    _silenceTimer?.cancel();
    setState(() => _isListening = false);
  }

  Future<void> _initialize() async {
    setState(() {
      _loadingCatalog = true;
      _loadingLocation = true;
    });

    try {
      final catalog = await _pharmacyService.fetchCatalog();
      GeoPoint? location;
      try {
        location = await _locationService.tryGetCurrentPosition();
      } catch (e) {
        debugPrint('Erreur localisation: $e');
      }

      if (!mounted) return;

      setState(() {
        _catalog = catalog;
        _filtered = catalog;
        _loadingCatalog = false;
        _isSearching = false;
        _userLocation = location;
        _locationUnavailable = location == null;
        _loadingLocation = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement du catalogue: $e');
      if (!mounted) return;
      setState(() {
        _catalog = [];
        _filtered = [];
        _loadingCatalog = false;
        _loadingLocation = false;
        _locationUnavailable = true;
      });
    }
    _speech = stt.SpeechToText();
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _loadingLocation = true;
    });

    try {
      final location = await _locationService.tryGetCurrentPosition();
      if (!mounted) return;

      setState(() {
        _userLocation = location;
        _locationUnavailable = location == null;
        _loadingLocation = false;
      });

      _applyFilter(_searchController.text);
    } catch (e) {
      debugPrint('Erreur rafraîchissement localisation: $e');
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationUnavailable = true;
      });
    }
  }

  Future<void> _applyFilter(String query) async {
    setState(() {
      _isSearching = query.isNotEmpty;
    });

    if (query.isEmpty) {
      setState(() {
        _filtered = _catalog;
      });
      return;
    }

    if (_userLocation != null) {
      try {
        final realTimeResults = await _pharmacyService.searchMedicationRealTime(
          query,
          latitude: _userLocation!.latitude,
          longitude: _userLocation!.longitude,
        );

        setState(() {
          _filtered = realTimeResults;
        });
      } catch (e) {
        debugPrint('Erreur recherche temps reel: $e');
        _fallbackLocalFilter(query);
      }
    } else {
      _fallbackLocalFilter(query);
    }
  }

  void _fallbackLocalFilter(String query) {
    final lower = query.toLowerCase();
    setState(() {
      _filtered = _catalog
          .where(
            (entry) =>
        entry.nom.toLowerCase().contains(lower) ||
            entry.dosage.toLowerCase().contains(lower),
      )
          .toList();
    });
  }

  void _onQueryChanged(String query) {
    _applyFilter(query);
  }

  void _onRecentSearchSelected(String term) {
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    _applyFilter(term);
  }

  void _clearSearch() {
    _searchController.clear();
    _applyFilter('');
  }

  StockStatus? _aggregateStatusFromList(
      List<MedicationAvailability> availabilities,
      ) {
    if (availabilities.isEmpty) return null;
    if (availabilities.any(
          (a) => a.medication.status == StockStatus.enStock,
    )) {
      return StockStatus.enStock;
    }
    if (availabilities.any(
          (a) => a.medication.status == StockStatus.stockLimite,
    )) {
      return StockStatus.stockLimite;
    }
    return StockStatus.rupture;
  }

  Color _statusColor(StockStatus? status) {
    switch (status) {
      case StockStatus.enStock:
        return AppColors.inStock;
      case StockStatus.stockLimite:
        return AppColors.limitedStock;
      case StockStatus.rupture:
        return AppColors.outOfStock;
      default:
        return AppColors.slate400;
    }
  }

  double? _distanceToPharmacy(Pharmacy pharmacy) {
    final location = _userLocation;
    final point = pharmacy.localisation;
    if (location == null || point == null) return null;
    return GeoUtils.haversineDistance(
      startLat: location.latitude,
      startLng: location.longitude,
      endLat: point.latitude,
      endLng: point.longitude,
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  List<MedicationAvailability> _sortedAvailabilities(
      MedicationCatalogEntry entry) {
    final List<MedicationAvailability> availabilities =
    List<MedicationAvailability>.from(entry.availabilities);
    if (_userLocation == null) return availabilities;

    final GeoPoint location = _userLocation!;
    final List<MedicationAvailability> filtered =
    availabilities.where((availability) {
      final point = availability.pharmacy.localisation;
      if (point == null) return false;
      final distance = GeoUtils.haversineDistance(
        startLat: location.latitude,
        startLng: location.longitude,
        endLat: point.latitude,
        endLng: point.longitude,
      );
      return distance <= _radiusMeters;
    }).toList();

    filtered.sort((a, b) {
      double distanceA = double.infinity;
      double distanceB = double.infinity;
      final pointA = a.pharmacy.localisation;
      final pointB = b.pharmacy.localisation;
      if (pointA != null) {
        distanceA = GeoUtils.haversineDistance(
          startLat: location.latitude,
          startLng: location.longitude,
          endLat: pointA.latitude,
          endLng: pointA.longitude,
        );
      }
      if (pointB != null) {
        distanceB = GeoUtils.haversineDistance(
          startLat: location.latitude,
          startLng: location.longitude,
          endLat: pointB.latitude,
          endLng: pointB.longitude,
        );
      }
      return distanceA.compareTo(distanceB);
    });

    return filtered;
  }

  void _openMap(MedicationCatalogEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            MedicationMapPage(entry: entry, initialUserLocation: _userLocation),
      ),
    );
  }

  Future<void> _openDirections(Pharmacy pharmacy) async {
    final point = pharmacy.localisation;
    if (point == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Localisation indisponible.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}&travelmode=driving',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loadingCatalog
            ? _buildLoadingState()
            : CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader()),

            // Search section
            SliverToBoxAdapter(child: _buildSearchSection()),

            // Location banner
            SliverToBoxAdapter(child: _buildLocationBanner()),

            // Quick actions
            SliverToBoxAdapter(child: _buildQuickActions()),

            // Results or History
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                child: _isSearching
                    ? _buildSearchResults()
                    : _buildDefaultContent(),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),

      // Floating AI Assistant Button
      floatingActionButton: _buildAIButton(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.medium,
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Chargement des pharmacies...",
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pharm",
                    style: AppTypography.headingSmall.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "Yaoundé, Cameroun",
                    style: AppTypography.caption.copyWith(
                      color: AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Actions
          Row(
            children: [
              // Refresh button
              _buildIconButton(
                icon: Icons.refresh_rounded,
                onTap: () async {
                  await _pharmacyService.invalidateCache();
                  await _initialize();
                },
              ),
              const SizedBox(width: 8),
              // Profile button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.secondary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.soft,
        ),
        child: Center(
          child: Icon(icon, color: AppColors.slate600, size: 22),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            "Bonjour 👋",
            style: AppTypography.displaySmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Quel médicament recherchez-vous ?",
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: 20),

          // Search bar
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _isSearchFocused
                          ? AppColors.primary
                          : AppColors.slate200,
                      width: _isSearchFocused ? 2 : 1.5,
                    ),
                    boxShadow: _isSearchFocused
                        ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                        : AppShadows.soft,
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onQueryChanged,
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        HistoryService.instance.add(value);
                        _applyFilter(value);
                      }
                    },
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.slate800,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Paracétamol, Amoxicilline...',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.slate400,
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(left: 16, right: 12),
                        child: Icon(
                          Icons.search_rounded,
                          color: _isSearchFocused
                              ? AppColors.primary
                              : AppColors.slate400,
                          size: 24,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0),
                      suffixIcon: _isSearching
                          ? IconButton(
                        onPressed: _clearSearch,
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.slate500,
                            size: 16,
                          ),
                        ),
                      )
                          : null,
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Voice/Send button
              GestureDetector(
                onTap: () {
                  if (_searchController.text.trim().isNotEmpty) {
                    HistoryService.instance.add(_searchController.text);
                    _applyFilter(_searchController.text);
                    FocusScope.of(context).unfocus();
                  } else {
                    _listen();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isListening
                        ? const LinearGradient(
                      colors: [AppColors.error, Color(0xFFFF6B6B)],
                    )
                        : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? AppColors.error : AppColors.primary)
                            .withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.stop_rounded
                        : (_searchController.text.isNotEmpty
                        ? Icons.send_rounded
                        : Icons.mic_rounded),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _loadingLocation
              ? LinearGradient(
            colors: [
              AppColors.slate100,
              AppColors.slate50,
            ],
          )
              : _userLocation != null
              ? LinearGradient(
            colors: [
              AppColors.success.withOpacity(0.08),
              AppColors.success.withOpacity(0.04),
            ],
          )
              : LinearGradient(
            colors: [
              AppColors.warning.withOpacity(0.08),
              AppColors.warning.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _loadingLocation
                ? AppColors.slate200
                : _userLocation != null
                ? AppColors.success.withOpacity(0.2)
                : AppColors.warning.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _loadingLocation
                    ? Colors.white
                    : _userLocation != null
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loadingLocation
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
                  : Icon(
                _userLocation != null
                    ? Icons.my_location_rounded
                    : Icons.location_off_rounded,
                color: _userLocation != null
                    ? AppColors.success
                    : AppColors.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _loadingLocation
                        ? "Localisation en cours..."
                        : _userLocation != null
                        ? "Position activée"
                        : "Localisation désactivée",
                    style: AppTypography.labelMedium.copyWith(
                      color: _loadingLocation
                          ? AppColors.slate600
                          : _userLocation != null
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _loadingLocation
                        ? "Recherche de votre position..."
                        : _userLocation != null
                        ? "Pharmacies triées par distance"
                        : "Activez le GPS pour un tri optimal",
                    style: AppTypography.caption.copyWith(
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
            if (!_loadingLocation)
              GestureDetector(
                onTap: _refreshLocation,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.camera_alt_rounded,
              title: "Scanner",
              subtitle: "Ordonnance",
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScannerPage()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionCard(
              icon: Icons.auto_awesome_rounded,
              title: "Assistant",
              subtitle: "IA Vocal",
              gradient: const LinearGradient(
                colors: [AppColors.secondary, AppColors.secondaryLight],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatAIScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (gradient as LinearGradient).colors.first.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // History section
        _buildHistorySection(),

        const SizedBox(height: 24),

        // Available medications
        SectionHeader(
          title: "Médicaments disponibles",
          actionText: "Voir tout",
          onActionTap: () {},
        ),
        const SizedBox(height: 16),
        _buildSearchResults(),
      ],
    );
  }

  Widget _buildHistorySection() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: HistoryService.instance.history,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: "Recherches récentes",
              actionText: "Effacer",
              onActionTap: () => HistoryService.instance.clear(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history.take(6).map((entry) {
                final parts = entry.split(':');
                final source = parts.isNotEmpty ? parts.first : 'Recherche';
                final term =
                parts.length > 1 ? parts.sublist(1).join(':') : entry;
                final isScanner = source == 'Scanner';

                return GestureDetector(
                  onTap: () => _onRecentSearchSelected(term),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate200),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isScanner ? Icons.document_scanner_outlined : Icons.history_rounded,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          term,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.slate700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => HistoryService.instance.remove(entry),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.slate400,
                            size: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: AppColors.slate400,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Aucun médicament trouvé",
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.slate700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Essayez une autre recherche ou vérifiez l'orthographe",
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = _filtered[index];
        return _buildMedicationCard(entry);
      },
    );
  }

  Widget _buildMedicationCard(MedicationCatalogEntry entry) {
    final availabilities = _sortedAvailabilities(entry);
    final status = _aggregateStatusFromList(availabilities);
    final color = _statusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          childrenPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.medication_rounded,
              color: color,
              size: 24,
            ),
          ),
          title: Text(
            entry.nom,
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.slate800,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                entry.dosage,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.slate500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  StatusBadge(
                    text: status?.label ?? 'Inconnu',
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${availabilities.length} pharmacie${availabilities.length > 1 ? 's' : ''}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.slate600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            if (availabilities.isNotEmpty)
              _buildPharmacyList(entry, availabilities),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: GradientButton(
                text: "Voir sur la carte",
                icon: Icons.map_rounded,
                onPressed: () => _openMap(entry),
                height: 48,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPharmacyList(
      MedicationCatalogEntry entry,
      List<MedicationAvailability> availabilities,
      ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: availabilities.take(3).map((availability) {
          final pharmacy = availability.pharmacy;
          final distance = _distanceToPharmacy(pharmacy);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.local_pharmacy_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pharmacy.nom,
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (distance != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDistance(distance),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (pharmacy.adresse != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    pharmacy.adresse!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.slate500,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.directions_rounded,
                        label: "Y aller",
                        onTap: () => _openDirections(pharmacy),
                        isPrimary: false,
                      ),
                    ),
                    if (pharmacy.telephone != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.phone_rounded,
                          label: "Appeler",
                          onTap: () => launchUrl(
                            Uri.parse('tel:${pharmacy.telephone}'),
                          ),
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isPrimary ? AppColors.primaryGradient : null,
          color: isPrimary ? null : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary
              ? null
              : Border.all(color: AppColors.primary, width: 1.5),
          boxShadow: isPrimary
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : AppColors.primary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isPrimary ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatAIScreen()),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  "Assistant IA",
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
