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

// ─────────────────────────────────────────────────────────────
// DESIGN TOKENS — palette "pharma Pro"
// Primary   : Teal profond   #0A6E6E  (confiance médicale)
// Accent    : Émeraude vif   #00BFA6  (disponibilité / vie)
// Warning   : Ambre doré     #F4A621
// Danger    : Corail         #F25C54
// Surface   : Blanc cassé    #F7FAFA
// Card bg   : Blanc pur      #FFFFFF
// Text h1   : Ardoise foncé  #0D1F2D
// Text body : Gris ardoise   #4A6572
// Border    : Gris perle     #DDE6E6
// ─────────────────────────────────────────────────────────────

class _PharmaColors {
  static const primary = Color(0xFF0A6E6E);
  static const primaryLight = Color(0xFF0D8C8C);
  static const primarySurface = Color(0xFFE6F4F4);
  static const accent = Color(0xFF00BFA6);
  static const accentSurface = Color(0xFFE0FAF7);
  static const warning = Color(0xFFF4A621);
  static const warningSurface = Color(0xFFFFF4E0);
  static const danger = Color(0xFFF25C54);
  static const dangerSurface = Color(0xFFFFEDEC);
  static const neutral = Color(0xFF64748B);
  static const neutralSurface = Color(0xFFF1F5F5);
  static const surface = Color(0xFFF7FAFA);
  static const cardBg = Color(0xFFFFFFFF);
  static const textH1 = Color(0xFF0D1F2D);
  static const textBody = Color(0xFF4A6572);
  static const textMuted = Color(0xFF8FA3AE);
  static const border = Color(0xFFDDE6E6);
  static const whatsapp = Color(0xFF25D366);
}

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
  static const double _nearbyRadiusMeters = 5000;
  static const int _nearbyPharmacyLimit = 5;

  late stt.SpeechToText _speech;
  late AnimationController _animationController;
  Timer? _silenceTimer;
  bool _isListening = false;
  final PharmacyService _pharmacyService = PharmacyService();
  final WhatsAppService _whatsAppService = WhatsAppService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchFocused = false;

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
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _searchFocusNode.addListener(() {
      setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
    _loadSearchHistory();
    _initialize();
    if (widget.scannedMedications != null &&
        widget.scannedMedications!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processScannedMedications();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scannedMedications != oldWidget.scannedMedications &&
        widget.scannedMedications != null &&
        widget.scannedMedications!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _processScannedMedications();
      });
    }
  }

  Future<void> _loadSearchHistory() async {
    await HistoryService.instance.load();
  }

  void _processScannedMedications() {
    if (widget.scannedMedications == null || widget.scannedMedications!.isEmpty)
      return;
    final searchText = widget.scannedMedications!.join(', ');
    _searchController.text = searchText;
    _applyFilter(searchText);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _silenceTimer?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      if (_isListening) _stopListening();
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('Statut: $val'),
        onError: (val) => debugPrint('Erreur: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _startSilenceTimer();
        _speech.listen(
          onResult: (val) {
            setState(() {
              _searchController.text = val.recognizedWords;
              if (val.recognizedWords.trim().isNotEmpty) _isSearching = true;
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
      debugPrint('Erreur chargement: $e');
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
    setState(() => _loadingLocation = true);
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
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        _locationUnavailable = true;
      });
    }
  }

  Future<void> _applyFilter(String query) async {
    setState(() => _isSearching = query.isNotEmpty);
    if (query.isEmpty) {
      setState(() => _filtered = _catalog);
      return;
    }
    if (_userLocation != null) {
      try {
        final realTimeResults = await _pharmacyService.searchMedicationRealTime(
          query,
          latitude: _userLocation!.latitude,
          longitude: _userLocation!.longitude,
        );
        setState(() => _filtered = realTimeResults);
      } catch (e) {
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
          .where((e) =>
              e.nom.toLowerCase().contains(lower) ||
              e.dosage.toLowerCase().contains(lower))
          .toList();
    });
  }

  void _onQueryChanged(String query) => _applyFilter(query);

  void _onRecentSearchSelected(String term) {
    _searchController.text = term;
    _searchController.selection =
        TextSelection.fromPosition(TextPosition(offset: term.length));
    _applyFilter(term);
  }

  void _clearSearch() {
    _searchController.clear();
    _applyFilter('');
  }

  StockStatus? _aggregateStatusFromList(List<MedicationAvailability> list) {
    if (list.isEmpty) return null;
    if (list.any((a) => a.medication.status == StockStatus.enStock))
      return StockStatus.enStock;
    if (list.any((a) => a.medication.status == StockStatus.stockLimite))
      return StockStatus.stockLimite;
    if (list.any((a) => a.medication.status == StockStatus.aConfirmer))
      return StockStatus.aConfirmer;
    return StockStatus.rupture;
  }

  Color _statusColor(StockStatus? status) {
    switch (status) {
      case StockStatus.enStock:
        return _PharmaColors.accent;
      case StockStatus.stockLimite:
        return _PharmaColors.warning;
      case StockStatus.rupture:
        return _PharmaColors.danger;
      case StockStatus.aConfirmer:
      default:
        return _PharmaColors.neutral;
    }
  }

  Color _statusSurface(StockStatus? status) {
    switch (status) {
      case StockStatus.enStock:
        return _PharmaColors.accentSurface;
      case StockStatus.stockLimite:
        return _PharmaColors.warningSurface;
      case StockStatus.rupture:
        return _PharmaColors.dangerSurface;
      default:
        return _PharmaColors.neutralSurface;
    }
  }

  double? _distanceToPharmacy(Pharmacy pharmacy) {
    final loc = _userLocation;
    final pt = pharmacy.localisation;
    if (loc == null || pt == null) return null;
    return GeoUtils.haversineDistance(
      startLat: loc.latitude,
      startLng: loc.longitude,
      endLat: pt.latitude,
      endLng: pt.longitude,
    );
  }

  String _formatDistance(double meters) {
    return meters >= 1000
        ? '${(meters / 1000).toStringAsFixed(1)} km'
        : '${meters.toStringAsFixed(0)} m';
  }

  List<MedicationAvailability> _sortedAvailabilities(
      MedicationCatalogEntry entry) {
    if (_userLocation == null) return [];
    final loc = _userLocation;
    final filtered = entry.availabilities.where((a) {
      final pt = a.pharmacy.localisation;
      if (pt == null) return false;
      return GeoUtils.haversineDistance(
            startLat: loc.latitude,
            startLng: loc.longitude,
            endLat: pt.latitude,
            endLng: pt.longitude,
          ) <=
          _nearbyRadiusMeters;
    }).toList();
    filtered.sort((a, b) {
      final ptA = a.pharmacy.localisation;
      final ptB = b.pharmacy.localisation;
      final dA = ptA == null
          ? double.infinity
          : GeoUtils.haversineDistance(
              startLat: loc.latitude,
              startLng: loc.longitude,
              endLat: ptA.latitude,
              endLng: ptA.longitude,
            );
      final dB = ptB == null
          ? double.infinity
          : GeoUtils.haversineDistance(
              startLat: loc.latitude,
              startLng: loc.longitude,
              endLat: ptB.latitude,
              endLng: ptB.longitude,
            );
      return dA.compareTo(dB);
    });
    return filtered.take(_nearbyPharmacyLimit).toList();
  }

  void _openMap(MedicationCatalogEntry entry) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          MedicationMapPage(entry: entry, initialUserLocation: _userLocation),
    ));
  }

  Future<void> _openDirections(Pharmacy pharmacy, {Color? accentColor}) async {
    final pt = pharmacy.localisation;
    if (pt == null) {
      _showSnack('Localisation indisponible pour cette pharmacie.');
      return;
    }
    final destLat = pt.latitude;
    final destLng = pt.longitude;
    if (destLat == 0 || destLng == 0) {
      _showSnack('Coordonnées de la pharmacie indisponibles.');
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
      _showSnack('Position utilisateur introuvable.');
      return;
    }
    final double startLat = userLoc.latitude;
    final double startLng = userLoc.longitude;
    if (startLat == 0 || startLng == 0) {
      _showSnack('Impossible de déterminer votre position.');
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
                )));
  }

  String? _primaryWhatsAppNumber(Pharmacy pharmacy) {
    final w = pharmacy.whatsapp?.trim();
    if (w != null && w.isNotEmpty) return w;
    final p = pharmacy.telephone?.trim();
    if (p != null && p.isNotEmpty) return p;
    return null;
  }

  Future<void> _makePhoneCall(Pharmacy pharmacy) async {
    final phone = pharmacy.telephone?.trim();
    if (phone == null || phone.isEmpty) {
      _showSnack('Numéro de téléphone indisponible.');
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) _showSnack("Impossible de lancer l'appel.");
  }

  Future<void> _openWhatsAppAvailability(
      Pharmacy pharmacy, String medicationName) async {
    final phone = _primaryWhatsAppNumber(pharmacy);
    if (phone == null) {
      _showSnack('Contact WhatsApp indisponible.');
      return;
    }
    final result = await _whatsAppService.sendAvailabilityRequest(
      phoneNumber: phone,
      pharmacyId: pharmacy.id,
      pharmacyName: pharmacy.nom,
      medicationName: medicationName,
    );
    if (!mounted) return;
    if (!result.success) {
      _showSnack(result.message ?? "Impossible d'envoyer le message WhatsApp.");
      return;
    }
    _showSnack(result.message ?? 'Demande envoyée.');
    if (result.conversationId != null) {
      await _showWhatsAppConversationDialog(
        conversationId: result.conversationId!,
        pharmacy: pharmacy,
        medicationName: medicationName,
      );
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: _PharmaColors.textH1,
      ),
    );
  }

  Future<void> _showWhatsAppConversationDialog({
    required String conversationId,
    required Pharmacy pharmacy,
    required String medicationName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _PharmaColors.whatsapp.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FaIcon(FontAwesomeIcons.whatsapp,
                      color: _PharmaColors.whatsapp, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pharmacy.nom,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _PharmaColors.textH1,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                height: 320,
                child: StreamBuilder<WhatsAppConversation?>(
                  stream:
                      _whatsAppService.watchConversation(conversationId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(
                          child: CircularProgressIndicator(
                              color: _PharmaColors.primary));
                    final conv = snapshot.data;
                    if (conv == null)
                      return const Center(
                          child: Text('Conversation introuvable.'));
                    return ListView.builder(
                      itemCount: conv.messages.length,
                      itemBuilder: (_, i) => _buildWhatsAppMessageBubble(
                        conv.messages[i],
                        pharmacy.nom,
                        medicationName,
                      ),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fermer',
                      style: TextStyle(color: _PharmaColors.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsAppMessageBubble(
    WhatsAppConversationMessage message,
    String pharmacyName,
    String medicationName,
  ) {
    final isOut = message.direction == WhatsAppMessageDirection.outgoing;
    final interp = !isOut
        ? _whatsAppService.interpretPharmacyReply(message.text,
            pharmacyName: pharmacyName, medicationName: medicationName)
        : null;
    return Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isOut
              ? _PharmaColors.accentSurface
              : _PharmaColors.neutralSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOut ? 16 : 4),
            bottomRight: Radius.circular(isOut ? 4 : 16),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message.text,
              style: const TextStyle(
                  fontSize: 13, color: _PharmaColors.textH1, height: 1.4)),
          if (interp != null) ...[
            const SizedBox(height: 6),
            Text(interp.summary,
                style: const TextStyle(
                    fontSize: 12,
                    color: _PharmaColors.accent,
                    fontWeight: FontWeight.w600)),
          ],
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LOCATION BANNER — redesign
  // ─────────────────────────────────────────────────────────────
  Widget _buildLocationBanner() {
    if (_loadingLocation) {
      return _LocationBanner(
        icon: Icons.location_searching,
        iconColor: _PharmaColors.primary,
        bgColor: _PharmaColors.primarySurface,
        borderColor: _PharmaColors.primary.withOpacity(0.2),
        label: 'Localisation en cours…',
        labelColor: _PharmaColors.primary,
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: _PharmaColors.primary),
        ),
      );
    }
    if (_userLocation != null) {
      return _LocationBanner(
        icon: Icons.my_location_rounded,
        iconColor: _PharmaColors.accent,
        bgColor: _PharmaColors.accentSurface,
        borderColor: _PharmaColors.accent.withOpacity(0.25),
        label: 'Localisation activée — recherche de proximité',
        labelColor: _PharmaColors.primary,
        trailing: GestureDetector(
          onTap: _refreshLocation,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _PharmaColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.refresh_rounded,
                color: _PharmaColors.accent, size: 18),
          ),
        ),
      );
    }
    return _LocationBanner(
      icon: Icons.location_off_rounded,
      iconColor: _PharmaColors.warning,
      bgColor: _PharmaColors.warningSurface,
      borderColor: _PharmaColors.warning.withOpacity(0.25),
      label: _locationUnavailable
          ? 'Localisation indisponible'
          : 'Activez votre localisation',
      labelColor: _PharmaColors.warning,
      trailing: GestureDetector(
        onTap: _refreshLocation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _PharmaColors.warning,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Activer',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PHARMACY CARD (availability tile) — redesign premium
  // ─────────────────────────────────────────────────────────────
  Widget _buildAvailabilityTiles(
    MedicationCatalogEntry entry,
    List<MedicationAvailability> availabilities,
  ) {
    if (availabilities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _PharmaColors.neutralSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 36, color: _PharmaColors.textMuted),
            ),
            const SizedBox(height: 12),
            const Text('Aucune pharmacie trouvée à proximité',
                style: TextStyle(
                    color: _PharmaColors.textBody,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );
    }

    return Column(
      children: availabilities.asMap().entries.map((e) {
        final idx = e.key;
        final avail = e.value;
        final pharmacy = avail.pharmacy;
        final med = avail.medication;
        final distance = _distanceToPharmacy(pharmacy);
        final hasPhone = pharmacy.telephone?.trim().isNotEmpty == true;
        final hasWA = _primaryWhatsAppNumber(pharmacy) != null;

        // Status config
        late String statusLabel;
        late Color statusColor;
        late Color statusSurface;
        late IconData statusIcon;
        switch (med.status) {
          case StockStatus.enStock:
            statusLabel = 'Disponible';
            statusColor = _PharmaColors.accent;
            statusSurface = _PharmaColors.accentSurface;
            statusIcon = Icons.check_circle_rounded;
            break;
          case StockStatus.stockLimite:
            statusLabel = 'Stock limité';
            statusColor = _PharmaColors.warning;
            statusSurface = _PharmaColors.warningSurface;
            statusIcon = Icons.warning_amber_rounded;
            break;
          case StockStatus.rupture:
            statusLabel = 'Rupture';
            statusColor = _PharmaColors.danger;
            statusSurface = _PharmaColors.dangerSurface;
            statusIcon = Icons.cancel_rounded;
            break;
          default:
            statusLabel = 'À confirmer';
            statusColor = _PharmaColors.neutral;
            statusSurface = _PharmaColors.neutralSurface;
            statusIcon = Icons.help_outline_rounded;
        }

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          duration: Duration(milliseconds: 280 + idx * 70),
          builder: (context, v, child) => Transform.translate(
            offset: Offset(0, 18 * (1 - v)),
            child: Opacity(opacity: v, child: child),
          ),
          child: Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
            decoration: BoxDecoration(
              color: _PharmaColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _PharmaColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: _PharmaColors.primary.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Status accent strip
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor, statusColor.withOpacity(0.4)],
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header row: name + distance pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pharmacy avatar icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _PharmaColors.primarySurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_pharmacy_rounded,
                                color: _PharmaColors.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pharmacy.nom,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: _PharmaColors.textH1,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(children: [
                                  const Icon(Icons.place_rounded,
                                      size: 12, color: _PharmaColors.textMuted),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      pharmacy.adresse ?? 'Adresse non renseignée',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: _PharmaColors.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                          if (distance != null) ...[
                            const SizedBox(width: 8),
                            _DistancePill(label: _formatDistance(distance)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Divider
                      Divider(color: _PharmaColors.border, height: 1),
                      const SizedBox(height: 14),

                      // ── Status + Price row
                      Row(children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon,
                                    size: 13, color: statusColor),
                                const SizedBox(width: 5),
                                Text(statusLabel,
                                    style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 0.2)),
                              ]),
                        ),
                        const Spacer(),
                        // Price
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _PharmaColors.neutralSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _PharmaColors.border, width: 1),
                          ),
                          child: Text(
                            med.prix > 0
                                ? '${med.prix.toStringAsFixed(0)} FCFA'
                                : 'Prix à confirmer',
                            style: const TextStyle(
                                color: _PharmaColors.textBody,
                                fontWeight: FontWeight.w700,
                                fontSize: 11),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),

                      // ── Action buttons
                      Row(children: [
                        // Itinéraire
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.route_rounded,
                            label: 'Itinéraire',
                            foreground: _PharmaColors.primary,
                            background: _PharmaColors.primarySurface,
                            onTap: () =>
                                _openDirections(pharmacy, accentColor: statusColor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Appeler
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.phone_rounded,
                            label: 'Appeler',
                            foreground: hasPhone
                                ? _PharmaColors.textBody
                                : _PharmaColors.textMuted,
                            background: _PharmaColors.neutralSurface,
                            onTap: hasPhone
                                ? () => _makePhoneCall(pharmacy)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // WhatsApp circle
                        _WhatsAppButton(
                          active: hasWA,
                          onTap: hasWA
                              ? () => _openWhatsAppAvailability(
                                  pharmacy, entry.nom)
                              : null,
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH RESULTS
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchResults() {
    if (_filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _PharmaColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 48, color: _PharmaColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('Aucun médicament trouvé',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _PharmaColors.textH1)),
            const SizedBox(height: 6),
            const Text('Essayez un autre terme de recherche',
                style:
                    TextStyle(fontSize: 13, color: _PharmaColors.textBody)),
          ]),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = _filtered[index];
        final availabilities = _sortedAvailabilities(entry);
        final status = _aggregateStatusFromList(availabilities);
        final statusColor = _statusColor(status);
        final statusSurface = _statusSurface(status);

        return _MedExpansionCard(
          entry: entry,
          availabilities: availabilities,
          statusColor: statusColor,
          statusSurface: statusSurface,
          userLocation: _userLocation,
          availabilityBuilder: () =>
              _buildAvailabilityTiles(entry, availabilities),
          onOpenMap: () => _openMap(entry),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HISTORY LIST
  // ─────────────────────────────────────────────────────────────
  Widget _buildHistoryList() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: HistoryService.instance.history,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(children: [
                Icon(Icons.history_rounded,
                    size: 40, color: _PharmaColors.textMuted),
                const SizedBox(height: 10),
                const Text('Aucune recherche récente',
                    style: TextStyle(
                        color: _PharmaColors.textMuted, fontSize: 13)),
              ]),
            ),
          );
        }
        return Column(
          children: history.asMap().entries.map((e) {
            final raw = e.value;
            final parts = raw.split(':');
            final source = parts.isNotEmpty ? parts.first : 'Recherche';
            final term =
                parts.length > 1 ? parts.sublist(1).join(':') : raw;
            final isScan = source == 'Cadnet';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _onRecentSearchSelected(term),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _PharmaColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _PharmaColors.border, width: 1),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isScan
                              ? _PharmaColors.primarySurface
                              : _PharmaColors.neutralSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isScan
                              ? Icons.document_scanner_rounded
                              : Icons.history_rounded,
                          color: isScan
                              ? _PharmaColors.primary
                              : _PharmaColors.neutral,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(term,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: _PharmaColors.textH1)),
                            Text(source,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: _PharmaColors.textMuted)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            HistoryService.instance.remove(raw),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _PharmaColors.neutralSurface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14,
                              color: _PharmaColors.textMuted),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PharmaColors.surface,
      appBar: _buildAppBar(),
      body: _loadingCatalog
          ? _buildLoadingState()
          : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _PharmaColors.cardBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
            height: 1, color: _PharmaColors.border, thickness: 1),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: _PharmaColors.neutralSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _PharmaColors.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: _PharmaColors.textH1),
          ),
        ),
      ),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [
              _PharmaColors.primary,
              _PharmaColors.accent,
            ]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.local_pharmacy_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        const Text(
          'pharma',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: _PharmaColors.textH1,
            letterSpacing: -0.5,
          ),
        ),
      ]),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _PharmaColors.neutralSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _PharmaColors.border),
            ),
            child: const Icon(Icons.account_circle_outlined,
                color: _PharmaColors.textBody, size: 20),
          ),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const SettingsScreen(userName: '')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _PharmaColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _PharmaColors.primary.withOpacity(0.2)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: _PharmaColors.primary, size: 20),
            ),
            tooltip: 'Recharger',
            onPressed: () async {
              await _pharmacyService.invalidateCache();
              await _initialize();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _PharmaColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                  color: _PharmaColors.primary, strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            const Text('Chargement du catalogue…',
                style: TextStyle(
                    color: _PharmaColors.textBody,
                    fontWeight: FontWeight.w500)),
          ]),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 24),

          // ── Page header
          _buildPageHeader(),
          const SizedBox(height: 20),

          // ── Location banner
          _buildLocationBanner(),
          const SizedBox(height: 20),

          // ── Search bar + action button
          _buildSearchRow(),
          const SizedBox(height: 16),

          // ── Scanner CTA
          _buildScannerCTA(),
          const SizedBox(height: 32),

          // ── Section title
          _buildSectionTitle(),
          const SizedBox(height: 16),

          // ── Content
          _isSearching
              ? _buildSearchResults()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHistoryList(),
                    const SizedBox(height: 28),
                    _buildSubSectionTitle('Médicaments disponibles'),
                    const SizedBox(height: 14),
                    _buildSearchResults(),
                  ],
                ),

          const SizedBox(height: 48),
        ]),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'Trouvez votre\nmédicament',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: _PharmaColors.textH1,
          height: 1.2,
          letterSpacing: -0.8,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Disponibilité en temps réel dans les pharmacies proches de vous',
        style: TextStyle(
          fontSize: 13,
          color: _PharmaColors.textBody,
          height: 1.4,
        ),
      ),
    ]);
  }

  Widget _buildSearchRow() {
    return Row(children: [
      Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _PharmaColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchFocused
                  ? _PharmaColors.primary
                  : _PharmaColors.border,
              width: _searchFocused ? 1.5 : 1,
            ),
            boxShadow: _searchFocused
                ? [
                    BoxShadow(
                      color: _PharmaColors.primary.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onQueryChanged,
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                HistoryService.instance.add(v);
                _applyFilter(v);
              }
            },
            style: const TextStyle(
                fontSize: 15, color: _PharmaColors.textH1),
            decoration: InputDecoration(
              hintText: 'Nom du médicament, dosage…',
              hintStyle: const TextStyle(
                  color: _PharmaColors.textMuted, fontSize: 14),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.search_rounded,
                    color: _searchFocused
                        ? _PharmaColors.primary
                        : _PharmaColors.textMuted,
                    size: 22),
              ),
              suffixIcon: _isSearching
                  ? GestureDetector(
                      onTap: _clearSearch,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _PharmaColors.neutralSurface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: _PharmaColors.textBody),
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: Colors.transparent,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      _buildSearchActionButton(),
    ]);
  }

  Widget _buildSearchActionButton() {
    final isActive = _isListening;
    final hasTerm = _searchController.text.isNotEmpty;
    return GestureDetector(
      onTap: () {
        if (hasTerm && !_isListening) {
          HistoryService.instance.add(_searchController.text);
          _applyFilter(_searchController.text);
          FocusScope.of(context).unfocus();
        } else {
          _listen();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [_PharmaColors.danger, const Color(0xFFD94040)]
                : hasTerm
                    ? [_PharmaColors.accent, _PharmaColors.primary]
                    : [_PharmaColors.primary, _PharmaColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isActive ? _PharmaColors.danger : _PharmaColors.primary)
                  .withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          isActive
              ? Icons.stop_rounded
              : hasTerm
                  ? Icons.send_rounded
                  : Icons.mic_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildScannerCTA() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<List<String>>(
          context,
          MaterialPageRoute(builder: (_) => const ScannerPage()),
        );
        if (result != null && result.isNotEmpty) {
          final text = result.join(', ');
          _searchController.text = text;
          _applyFilter(text);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: _PharmaColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _PharmaColors.primary.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _PharmaColors.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_PharmaColors.primary, _PharmaColors.accent],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.document_scanner_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Importer un Cadnet',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _PharmaColors.textH1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Scannez votre ordonnance pour rechercher automatiquement',
                  style: TextStyle(
                      fontSize: 11, color: _PharmaColors.textBody),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _PharmaColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: _PharmaColors.primary),
          ),
        ]),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Row(children: [
      Container(
        width: 4,
        height: 22,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_PharmaColors.primary, _PharmaColors.accent],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        _isSearching ? 'Résultats de recherche' : 'Recherches récentes',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _PharmaColors.textH1,
          letterSpacing: -0.4,
        ),
      ),
    ]);
  }

  Widget _buildSubSectionTitle(String title) {
    return Row(children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          color: _PharmaColors.accent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _PharmaColors.textH1,
          letterSpacing: -0.3,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// COMPOSANTS HELPER
// ─────────────────────────────────────────────────────────────

class _LocationBanner extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String label;
  final Color labelColor;
  final Widget trailing;

  const _LocationBanner({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.label,
    required this.labelColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: labelColor)),
        ),
        trailing,
      ]),
    );
  }
}

class _DistancePill extends StatelessWidget {
  final String label;
  const _DistancePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_PharmaColors.primary, _PharmaColors.accent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _PharmaColors.primary.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.near_me_rounded, size: 10, color: Colors.white),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11)),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _PharmaColors.border, width: 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground)),
        ]),
      ),
    );
  }
}

class _WhatsAppButton extends StatelessWidget {
  final bool active;
  final VoidCallback? onTap;
  const _WhatsAppButton({required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color:
              active ? _PharmaColors.whatsapp : _PharmaColors.neutralSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active
                  ? _PharmaColors.whatsapp.withOpacity(0.3)
                  : _PharmaColors.border,
              width: 1),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _PharmaColors.whatsapp.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: FaIcon(FontAwesomeIcons.whatsapp,
              color: active ? Colors.white : _PharmaColors.textMuted,
              size: 20),
        ),
      ),
    );
  }
}

class _MedExpansionCard extends StatelessWidget {
  final MedicationCatalogEntry entry;
  final List<MedicationAvailability> availabilities;
  final Color statusColor;
  final Color statusSurface;
  final dynamic userLocation;
  final Widget Function() availabilityBuilder;
  final VoidCallback onOpenMap;

  const _MedExpansionCard({
    required this.entry,
    required this.availabilities,
    required this.statusColor,
    required this.statusSurface,
    required this.userLocation,
    required this.availabilityBuilder,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _PharmaColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _PharmaColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Theme(
          data: Theme.of(context)
              .copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            childrenPadding: const EdgeInsets.only(bottom: 14),
            leading: Container(
              width: 5,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [statusColor, statusColor.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            title: Text(
              entry.nom,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _PharmaColors.textH1,
                letterSpacing: -0.2,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Flexible(
                  child: Text(entry.dosage,
                      style: const TextStyle(
                          color: _PharmaColors.textBody, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _PharmaColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.store_rounded,
                        size: 11, color: _PharmaColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${availabilities.length} pharmacie${availabilities.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _PharmaColors.primary,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            children: [
              if (userLocation != null && availabilities.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _PharmaColors.warningSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              _PharmaColors.warning.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: _PharmaColors.warning),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Prix et disponibilité affichés par pharmacie à proximité.',
                          style: TextStyle(
                              fontSize: 12,
                              color: _PharmaColors.warning,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ]),
                  ),
                ),
              if (userLocation == null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Text(
                    'Activez la localisation pour voir les pharmacies proches.',
                    style: const TextStyle(
                        color: _PharmaColors.textBody, fontSize: 13),
                  ),
                ),
              if (availabilities.isNotEmpty) availabilityBuilder(),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onOpenMap,
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text('Voir sur la carte',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _PharmaColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
