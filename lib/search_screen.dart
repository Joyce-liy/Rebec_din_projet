import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pharma/profil.dart';
import 'package:pharma/map/medication_map_page.dart';
import 'package:pharma/map/in_app_navigation_page.dart';
import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/scanner_page.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/services/whatsapp_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pharma/services/history_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

class SearchScreen extends StatefulWidget {
  final List<String>? scannedMedications;

  const SearchScreen({
    super.key,
    required void Function(bool isFocused) onSearchFocusChanged,
    this.scannedMedications,
  });

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late AnimationController _animationController;
  Timer? _silenceTimer;
  bool _isListening = false;
  final PharmacyService _pharmacyService = PharmacyService();
  final WhatsAppService _whatsAppService = WhatsAppService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  List<MedicationCatalogEntry> _catalog = [];
  List<MedicationCatalogEntry> _filtered = [];
  bool _loadingCatalog = true;
  bool _loadingLocation = true;
  bool _isSearching = false;
  bool _locationUnavailable = false;
  dynamic _userLocation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadSearchHistory();
    _initialize();

    // Traiter les médicaments scannés s'ils existent
    if (widget.scannedMedications != null &&
        widget.scannedMedications!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processScannedMedications();
      });
    }
  }

  Future<void> _loadSearchHistory() async {
    await HistoryService.instance.load();
  }

  void _processScannedMedications() {
    if (widget.scannedMedications == null || widget.scannedMedications!.isEmpty)
      return;

    // Joindre tous les médicaments avec un séparateur
    final searchText = widget.scannedMedications!.join(', ');
    _searchController.text = searchText;
    _applyFilter(searchText);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _silenceTimer?.cancel();
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
      setState(() {});

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
    if (availabilities.isEmpty) {
      return null;
    }
    if (availabilities.any(
      (availability) => availability.medication.status == StockStatus.enStock,
    )) {
      return StockStatus.enStock;
    }
    if (availabilities.any(
      (availability) =>
          availability.medication.status == StockStatus.stockLimite,
    )) {
      return StockStatus.stockLimite;
    }
    if (availabilities.any(
      (availability) =>
          availability.medication.status == StockStatus.aConfirmer,
    )) {
      return StockStatus.aConfirmer;
    }
    return StockStatus.rupture;
  }

  Color _statusColor(StockStatus? status) {
    switch (status) {
      case StockStatus.enStock:
        return const Color(0xFF10B981);
      case StockStatus.stockLimite:
        return const Color(0xFFF59E0B);
      case StockStatus.rupture:
        return const Color(0xFFEF4444);
      case StockStatus.aConfirmer:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  double? _distanceToPharmacy(Pharmacy pharmacy) {
    final location = _userLocation;
    final point = pharmacy.localisation;
    if (location == null || point == null) {
      return null;
    }
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

  String _formatRelativeTime(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) {
      return "a l'instant";
    }
    if (diff.inMinutes < 60) {
      return 'il y a ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'il y a ${diff.inHours} h';
    }
    return 'il y a ${diff.inDays} j';
  }

  List<MedicationAvailability> _sortedAvailabilities(
    MedicationCatalogEntry entry,
  ) {
    final List<MedicationAvailability> availabilities =
        List<MedicationAvailability>.from(entry.availabilities);
    if (_userLocation == null) {
      return availabilities;
    }
    final dynamic location = _userLocation;
    final List<MedicationAvailability> filtered = availabilities
        .where((availability) => availability.pharmacy.localisation != null)
        .toList();

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

  Future<void> _openDirections(Pharmacy pharmacy, {Color? accentColor}) async {
    // Remplacement local pour ouverture directions
    final dynamic point = pharmacy.localisation;
    if (point == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Localisation indisponible pour cette pharmacie.'),
          ),
        );
      }
      return;
    }

    double destLat = 0.0;
    double destLng = 0.0;
    try {
      final a = (point is Map)
          ? (point['latitude'] ?? point['lat'])
          : ((point as dynamic).latitude ?? (point as dynamic).lat);
      final b = (point is Map)
          ? (point['longitude'] ?? point['lng'] ?? point['lon'])
          : ((point as dynamic).longitude ??
                (point as dynamic).lng ??
                (point as dynamic).lon);
      if (a is num) destLat = a.toDouble();
      if (b is num) destLng = b.toDouble();
    } catch (_) {}

    if (destLat == 0.0 || destLng == 0.0) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordonnées de la pharmacie indisponibles.'),
          ),
        );
      return;
    }

    dynamic userLoc = _userLocation;
    if (userLoc == null) {
      try {
        userLoc = await _locationService.tryGetCurrentPosition();
        if (userLoc != null) _userLocation = userLoc;
      } catch (_) {}
    }

    if (userLoc == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Position utilisateur introuvable.')),
        );
      return;
    }

    double startLat = 0.0;
    double startLng = 0.0;
    try {
      final sa = (userLoc is Map)
          ? (userLoc['latitude'] ?? userLoc['lat'])
          : (userLoc.latitude ?? (userLoc as dynamic).lat);
      final sb = (userLoc is Map)
          ? (userLoc['longitude'] ?? userLoc['lng'] ?? userLoc['lon'])
          : (userLoc.longitude ??
                (userLoc as dynamic).lng ??
                (userLoc as dynamic).lon);
      if (sa is num) startLat = sa.toDouble();
      if (sb is num) startLng = sb.toDouble();
    } catch (_) {}

    if (startLat == 0.0 || startLng == 0.0) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de déterminer votre position.'),
          ),
        );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppNavigationPage(
          startLat: startLat,
          startLng: startLng,
          destLat: destLat,
          destLng: destLng,
          pharmacyName: pharmacy.nom,
          accentColor: accentColor,
        ),
      ),
    );
  }

  String? _primaryWhatsAppNumber(Pharmacy pharmacy) {
    final whatsapp = pharmacy.whatsapp?.trim();
    if (whatsapp != null && whatsapp.isNotEmpty) {
      return whatsapp;
    }
    final phone = pharmacy.telephone?.trim();
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return null;
  }

  Future<void> _makePhoneCall(Pharmacy pharmacy) async {
    final phone = pharmacy.telephone?.trim();
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numero de telephone indisponible.')),
        );
      }
      return;
    }

    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de lancer l'appel.")),
      );
    }
  }

  Future<void> _openWhatsAppAvailability(
    Pharmacy pharmacy,
    String medicationName,
  ) async {
    final phone = _primaryWhatsAppNumber(pharmacy);
    if (phone == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact WhatsApp indisponible.')),
        );
      }
      return;
    }

    final launched = await _whatsAppService.openAvailabilityRequest(
      phoneNumber: phone,
      pharmacyName: pharmacy.nom,
      medicationName: medicationName,
    );

    if (!mounted) {
      return;
    }

    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
      );
      return;
    }

    await _showWhatsAppReplyDialog(pharmacy, medicationName);
  }

  Future<void> _showWhatsAppReplyDialog(
    Pharmacy pharmacy,
    String medicationName,
  ) async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Interpreter la reponse'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quand la pharmacie repond sur WhatsApp, copiez sa reponse ici.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Ex: Oui disponible a 1500 FCFA',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Plus tard'),
            ),
            ElevatedButton(
              onPressed: () {
                final reply = controller.text.trim();
                if (reply.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Collez la reponse recue.')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop();
                _showInterpretationResult(
                  pharmacy: pharmacy,
                  medicationName: medicationName,
                  reply: reply,
                );
              },
              child: const Text('Interpreter'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _showInterpretationResult({
    required Pharmacy pharmacy,
    required String medicationName,
    required String reply,
  }) async {
    final interpretation = _whatsAppService.interpretPharmacyReply(
      reply,
      pharmacyName: pharmacy.nom,
      medicationName: medicationName,
    );

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reponse interpretee'),
        content: Text(interpretation.summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(StockStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBanner() {
    if (_loadingLocation) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981).withOpacity(0.1),
              const Color(0xFF059669).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF10B981),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Localisation en cours...',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF047857),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_userLocation != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF10B981).withOpacity(0.1),
              const Color(0xFF059669).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.my_location,
                color: Color(0xFF047857),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Localisation activée',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF047857),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _refreshLocation,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.refresh,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.1),
            const Color(0xFFD97706).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_off,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _locationUnavailable
                  ? 'Localisation indisponible'
                  : 'Activez votre localisation',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFFD97706),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _refreshLocation,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Activer',
                  style: TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityTiles(
    MedicationCatalogEntry entry,
    List<MedicationAvailability> availabilities,
  ) {
    if (availabilities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Aucune pharmacie Firebase trouvee',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: availabilities.asMap().entries.map((mapEntry) {
        final index = mapEntry.key;
        final availability = mapEntry.value;
        final pharmacy = availability.pharmacy;
        final medication = availability.medication;
        final distance = _distanceToPharmacy(pharmacy);
        final hasPhone = pharmacy.telephone?.trim().isNotEmpty == true;
        final hasWhatsApp = _primaryWhatsAppNumber(pharmacy) != null;

        // Determine status label & color for badge
        String statusLabel;
        Color statusBadgeColor;
        IconData statusIcon;
        switch (medication.status) {
          case StockStatus.enStock:
            statusLabel = 'DISPONIBLE';
            statusBadgeColor = const Color(0xFF059669);
            statusIcon = Icons.check_circle;
            break;
          case StockStatus.stockLimite:
            statusLabel = 'STOCK LIMITÉ';
            statusBadgeColor = const Color(0xFFF59E0B);
            statusIcon = Icons.warning_rounded;
            break;
          case StockStatus.rupture:
            statusLabel = 'RUPTURE';
            statusBadgeColor = const Color(0xFFEF4444);
            statusIcon = Icons.cancel;
            break;
          case StockStatus.aConfirmer:
          default:
            statusLabel = 'DISPONIBLE';
            statusBadgeColor = const Color(0xFF059669);
            statusIcon = Icons.check_circle;
            break;
        }

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          duration: Duration(milliseconds: 300 + (index * 80)),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 15 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Pharmacy Name (centered) ──
                      Text(
                        pharmacy.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // ── Address (centered, lighter) ──
                      Text(
                        pharmacy.adresse ?? 'Adresse indisponible',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),

                      // ── Status + Price badges row ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: statusBadgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 14,
                                  color: statusBadgeColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusBadgeColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Price badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              medication.prix > 0
                                  ? '${medication.prix.toStringAsFixed(0)} FCFA'
                                  : 'Prix à confirmer',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Action buttons row: Itinéraire + Appeler + WhatsApp FAB ──
                      Row(
                        children: [
                          // Itinéraire button
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openDirections(
                                pharmacy,
                                accentColor: statusBadgeColor,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFB),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.route_rounded,
                                      size: 16,
                                      color: statusBadgeColor,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Itinéraire',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Appeler button
                          Expanded(
                            child: GestureDetector(
                              onTap: hasPhone
                                  ? () => _makePhoneCall(pharmacy)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFB),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 16,
                                      color: hasPhone
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Appeler',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: hasPhone
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // WhatsApp floating circle button
                          GestureDetector(
                            onTap: hasWhatsApp
                                ? () => _openWhatsAppAvailability(
                                    pharmacy,
                                    entry.nom,
                                  )
                                : null,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: hasWhatsApp
                                    ? const Color(0xFF25D366)
                                    : const Color(0xFFE0E0E0),
                                shape: BoxShape.circle,
                                boxShadow: hasWhatsApp
                                    ? [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF25D366,
                                          ).withOpacity(0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: const Center(
                                child: FaIcon(
                                  FontAwesomeIcons.whatsapp,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Distance badge (top-right floating pill) ──
                if (distance != null)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _formatDistance(distance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults() {
    if (_filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Aucun médicament trouvé',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Essayez avec un autre terme de recherche',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = _filtered[index];
        final availabilities = _sortedAvailabilities(entry);
        final status = _aggregateStatusFromList(availabilities);
        final color = _statusColor(status);

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.only(bottom: 12),
              leading: Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              title: Text(
                entry.nom,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1F2937),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.dosage,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${availabilities.length} pharmacies',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              children: [
                if (_userLocation != null && availabilities.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.amber[800],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Pharmacies chargees depuis Firebase. Confirmez disponibilite et prix via WhatsApp.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_userLocation == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      'Activez la localisation pour trier les pharmacies par distance.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                if (_userLocation != null && availabilities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      'Aucune pharmacie Firebase active trouvee.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                if (availabilities.isNotEmpty)
                  _buildAvailabilityTiles(entry, availabilities),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openMap(entry),
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text(
                        'Voir sur la carte',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: HistoryService.instance.history,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune recherche récente',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final entry = history[index];
            final parts = entry.split(':');
            final source = parts.isNotEmpty ? parts.first : 'Recherche';
            final term = parts.length > 1 ? parts.sublist(1).join(':') : entry;

            final IconData icon = source == 'Scanner'
                ? Icons.document_scanner_outlined
                : Icons.history;

            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF10B981), size: 20),
                ),
                title: Text(
                  term,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
                subtitle: Text(
                  source,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                onTap: () => _onRecentSearchSelected(term),
                trailing: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => HistoryService.instance.remove(entry),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black87,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_circle_outlined,
                color: Colors.black87,
                size: 22,
              ),
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(userName: ''),
                ),
              );
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.refresh,
                color: Color(0xFF10B981),
                size: 22,
              ),
            ),
            tooltip: 'Recharger',
            onPressed: () async {
              await _pharmacyService.invalidateCache();
              await _initialize();
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _loadingCatalog
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'Recherche de Médicaments',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildLocationBanner(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onQueryChanged,
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  HistoryService.instance.add(value);
                                  _applyFilter(value);
                                }
                              },
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Rechercher un médicament...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 15,
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.search,
                                    color: Colors.grey[400],
                                    size: 24,
                                  ),
                                ),
                                suffixIcon: _isSearching
                                    ? Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          onTap: _clearSearch,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.grey[400],
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey[200]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF10B981),
                                    width: 2,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (_searchController.text.trim().isNotEmpty) {
                                HistoryService.instance.add(
                                  _searchController.text,
                                );
                                _applyFilter(_searchController.text);
                                FocusScope.of(context).unfocus();
                              } else {
                                _listen();
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isListening
                                      ? [
                                          const Color(0xFFEF4444),
                                          const Color(0xFFDC2626),
                                        ]
                                      : (_searchController.text.isNotEmpty
                                            ? [
                                                const Color(0xFF10B981),
                                                const Color(0xFF059669),
                                              ]
                                            : [
                                                const Color(0xFF10B981),
                                                const Color(0xFF059669),
                                              ]),
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (_isListening
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF10B981))
                                            .withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isListening
                                    ? Icons.stop_rounded
                                    : (_searchController.text.isNotEmpty
                                          ? Icons.send_rounded
                                          : Icons.mic),
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withOpacity(0.9),
                            const Color(0xFF059669),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final result = await Navigator.push<List<String>>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ScannerPage(),
                              ),
                            );

                            // Si des médicaments ont été retournés, les afficher
                            if (result != null && result.isNotEmpty) {
                              final searchText = result.join(', ');
                              _searchController.text = searchText;
                              _applyFilter(searchText);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Scanner une ordonnance',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _isSearching
                          ? 'Résultats trouvés'
                          : 'Recherches récentes',
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isSearching
                        ? _buildSearchResults()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHistoryList(),
                              const SizedBox(height: 32),
                              const Text(
                                'Médicaments disponibles',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSearchResults(),
                            ],
                          ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
