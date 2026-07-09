import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/services/whatsapp_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pharma/map/custom_map_theme.dart';
import 'package:pharma/map/in_app_navigation_page.dart';
import 'package:pharma/widgets/shimmer_widget.dart';

// Palette locale — blue médical
class _N {
  static const primary    = Color(0xFF2563EB);
  static const primarySurf= Color(0xFFEFF6FF);
  static const accent     = Color(0xFF10B981);  // vert disponibilité
  static const accentSurf = Color(0xFFD1FAE5);
  static const warning    = Color(0xFFF59E0B);
  static const danger     = Color(0xFFEF4444);
  static const neutral    = Color(0xFF64748B);
  static const neutralSurf= Color(0xFFF1F5F9);
  static const surface    = Color(0xFFF8FAFD);
  static const cardBg     = Color(0xFFFFFFFF);
  static const textH1     = Color(0xFF0D1B2A);
  static const textBody   = Color(0xFF4A5568);
  static const textMuted  = Color(0xFF94A3B8);
  static const border     = Color(0xFFE2E8F0);
  static const whatsapp   = Color(0xFF25D366);
}

class NearbyPharmaciesScreen extends StatefulWidget {
  const NearbyPharmaciesScreen({super.key});

  @override
  State<NearbyPharmaciesScreen> createState() => _NearbyPharmaciesScreenState();
}

class _NearbyPharmaciesScreenState extends State<NearbyPharmaciesScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  final WhatsAppService _whatsAppService = WhatsAppService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  List<Pharmacy> _pharmacies = [];
  bool _isLoading = true;
  String? _error;
  dynamic _userLocation;
  bool _mapReady = false;
  String _locationName = 'Localisation...';

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
  }

  Future<void> _loadPharmacies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final location = await _locationService.tryGetCurrentPosition();
      if (location == null) {
        setState(() {
          _error =
              "Impossible de récupérer votre localisation. Vérifiez vos paramètres GPS.";
          _isLoading = false;
        });
        return;
      }

      _userLocation = location;
      _locationName = 'Yaoundé';

      final pharmacies = await _pharmacyService.fetchNearbyPharmacies(
        latitude: (location as dynamic).latitude as double,
        longitude: (location as dynamic).longitude as double,
      );

      pharmacies.sort((a, b) {
        final distA = GeoUtils.haversineDistance(
          startLat: (location as dynamic).latitude as double,
          startLng: (location as dynamic).longitude as double,
          endLat: a.localisation!.latitude,
          endLng: a.localisation!.longitude,
        );
        final distB = GeoUtils.haversineDistance(
          startLat: (location as dynamic).latitude as double,
          startLng: (location as dynamic).longitude as double,
          endLat: b.localisation!.latitude,
          endLng: b.localisation!.longitude,
        );
        return distA.compareTo(distB);
      });

      setState(() {
        _pharmacies = pharmacies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Erreur lors de la récupération des pharmacies: $e";
        _isLoading = false;
      });
    }
  }

  // ──────────────────────────────────────────
  // Actions
  // ──────────────────────────────────────────

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer l\'appel.')),
        );
      }
    }
  }

  String? _primaryWhatsAppNumber(Pharmacy pharmacy) {
    final whatsapp = pharmacy.whatsapp?.trim();
    if (whatsapp != null && whatsapp.isNotEmpty) return whatsapp;
    final phone = pharmacy.telephone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return null;
  }

  Future<void> _openWhatsAppAvailability(Pharmacy pharmacy) async {
    final phoneNumber = _primaryWhatsAppNumber(pharmacy);
    if (phoneNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact WhatsApp indisponible.')),
      );
      return;
    }
    final medicationName = await _askMedicationName();
    if (medicationName == null) return;

    final result = await _whatsAppService.sendAvailabilityRequest(
      phoneNumber: phoneNumber,
      pharmacyId: pharmacy.id,
      pharmacyName: pharmacy.nom,
      medicationName: medicationName,
    );
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? "Impossible d'envoyer le message WhatsApp.",
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Demande WhatsApp envoyee.')),
    );
    final conversationId = result.conversationId;
    if (conversationId != null) {
      await _showWhatsAppConversationDialog(
        conversationId: conversationId,
        pharmacy: pharmacy,
        medicationName: medicationName,
      );
    }
  }

  Future<void> _showWhatsAppConversationDialog({
    required String conversationId,
    required Pharmacy pharmacy,
    required String medicationName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('WhatsApp - ${pharmacy.nom}'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: StreamBuilder<WhatsAppConversation?>(
              stream: _whatsAppService.watchConversation(conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final conversation = snapshot.data;
                if (conversation == null) {
                  return const Center(
                    child: Text('Conversation introuvable.'),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _N.textBody,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: conversation.messages.length,
                        itemBuilder: (context, index) {
                          return _buildWhatsAppMessageBubble(
                            conversation.messages[index],
                            pharmacy.nom,
                            medicationName,
                          );
                        },
                      ),
                    ),
                    if (conversation.isWaitingForReply)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'En attente de reponse automatique...',
                          style: const TextStyle(
                            color: _N.neutral,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWhatsAppMessageBubble(
    WhatsAppConversationMessage message,
    String pharmacyName,
    String medicationName,
  ) {
    final isOutgoing = message.direction == WhatsAppMessageDirection.outgoing;
    final isIncoming = message.direction == WhatsAppMessageDirection.incoming;
    final interpretation = isIncoming
        ? _whatsAppService.interpretPharmacyReply(
            message.text,
            pharmacyName: pharmacyName,
            medicationName: medicationName,
          )
        : null;

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isOutgoing ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isOutgoing ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (interpretation != null) ...[
              const SizedBox(height: 8),
              Text(
                interpretation.summary,
                style: const TextStyle(
                  color: _N.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<String?> _askMedicationName() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Médicament recherché'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Ex: Paracetamol 500 mg',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.of(ctx).pop(v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _N.primary,
            ),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _showWhatsAppReplyDialog(
      Pharmacy pharmacy, String medicationName) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Interpréter la réponse'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Quand la pharmacie répond, copiez son message ici.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ex: Oui disponible à 1500 FCFA',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              final reply = controller.text.trim();
              if (reply.isEmpty) return;
              final interpretation =
                  _whatsAppService.interpretPharmacyReply(
                reply,
                pharmacyName: pharmacy.nom,
                medicationName: medicationName,
              );
              Navigator.of(ctx).pop();
              showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Réponse interprétée'),
                  content: Text(interpretation.summary),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(c).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Interpréter'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _openItineraire(Pharmacy pharmacy) async {
    final dynamic point = pharmacy.localisation;
    if (point == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Localisation indisponible pour cette pharmacie.')));
      return;
    }

    double destLat = 0.0;
    double destLng = 0.0;
    try {
      final a = (point is Map) ? (point['latitude'] ?? point['lat']) : ((point as dynamic).latitude ?? (point as dynamic).lat);
      final b = (point is Map) ? (point['longitude'] ?? point['lng'] ?? point['lon']) : ((point as dynamic).longitude ?? (point as dynamic).lng ?? (point as dynamic).lon);
      if (a is num) destLat = a.toDouble();
      if (b is num) destLng = b.toDouble();
    } catch (_) {}

    if (destLat == 0.0 || destLng == 0.0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordonnées de la pharmacie indisponibles.')));
      return;
    }

    // Récupérer position utilisateur (cache local ou via service)
    dynamic userLoc = _userLocation;
    if (userLoc == null) {
      try {
        userLoc = await _locationService.tryGetCurrentPosition();
        if (userLoc != null) _userLocation = userLoc;
      } catch (_) {}
    }

    if (userLoc == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Position utilisateur introuvable.')));
      return;
    }

    double startLat = 0.0;
    double startLng = 0.0;
    try {
      final sa = (userLoc is Map) ? (userLoc['latitude'] ?? userLoc['lat']) : (userLoc.latitude ?? (userLoc as dynamic).lat);
      final sb = (userLoc is Map) ? (userLoc['longitude'] ?? userLoc['lng'] ?? userLoc['lon']) : (userLoc.longitude ?? (userLoc as dynamic).lng ?? (userLoc as dynamic).lon);
      if (sa is num) startLat = sa.toDouble();
      if (sb is num) startLng = sb.toDouble();
    } catch (_) {}

    if (startLat == 0.0 || startLng == 0.0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de déterminer votre position.')));
      return;
    }

    // Ouvrir la page de navigation intégrée
    Navigator.push(context, MaterialPageRoute(builder: (_) => InAppNavigationPage(
      startLat: startLat,
      startLng: startLng,
      destLat: destLat,
      destLng: destLng,
      pharmacyName: pharmacy.nom,
    )));
  }

  // ──────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  double? _getDistance(Pharmacy pharmacy) {
    if (_userLocation == null || pharmacy.localisation == null) return null;
    return GeoUtils.haversineDistance(
      startLat: (_userLocation as dynamic).latitude as double,
      startLng: (_userLocation as dynamic).longitude as double,
      endLat: pharmacy.localisation!.latitude,
      endLng: pharmacy.localisation!.longitude,
    );
  }

  LatLng _mapCenter() {
    if (_userLocation != null) {
      return LatLng(
        (_userLocation as dynamic).latitude as double,
        (_userLocation as dynamic).longitude as double,
      );
    }
    return const LatLng(3.8667, 11.5167); // Yaoundé default
  }

  // ──────────────────────────────────────────
  // Map markers
  // ──────────────────────────────────────────

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];

    for (final pharmacy in _pharmacies) {
      final point = pharmacy.localisation;
      if (point == null) continue;

      markers.add(
        Marker(
          width: 180,
          height: 50,
          point: LatLng(point.latitude, point.longitude),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Blue circle with + (croix pharmacie)
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: _N.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x402563EB),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 4),
              // Name label
              Container(
                constraints: const BoxConstraints(maxWidth: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  pharmacy.nom,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _N.textH1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  // ──────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _N.surface,
        appBar: AppBar(
          backgroundColor: _N.surface,
          elevation: 0,
          title: const Text(
            'Pharmacies proches',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: _N.textH1,
            ),
          ),
        ),
        body: const NearbyLoadingSkeleton(),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _N.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _N.warning.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_off_rounded,
                      size: 48, color: _N.warning),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Localisation indisponible',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _N.textH1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _N.textBody, fontSize: 13, height: 1.5)),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _loadPharmacies,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _N.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ─── MAP SECTION ───
            Expanded(
              child: Stack(
                children: [
                  // Map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter(),
                      initialZoom: 14.0,
                      onMapReady: () {
                        setState(() => _mapReady = true);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: MapStyles.mapboxUrl,
                        fallbackUrl: MapStyles.osmStandardUrl,
                        userAgentPackageName: 'com.example.pharma',
                        maxZoom: 19,
                      ),
                      MarkerLayer(markers: _buildMarkers()),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('© Mapbox'),
                          TextSourceAttribution('© OpenStreetMap'),
                        ],
                      ),
                    ],
                  ),

                  // Location bar at top
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x20000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: _N.primary, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Localisation : $_locationName',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _N.textH1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── BOTTOM PANEL ───
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Bottom panel with horizontal pharmacy cards
  // ──────────────────────────────────────────

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _N.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle drag indicator
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _N.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_N.primary, Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Pharmacies à proximité',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _N.textH1,
                  letterSpacing: -0.3,
                ),
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Rayon de 5 km — triées par distance',
              style: TextStyle(fontSize: 13, color: _N.textMuted),
            ),
          ),

          // Horizontal pharmacy cards
          if (_pharmacies.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucune pharmacie trouvée.'),
            )
          else
            SizedBox(
              height: 210,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _pharmacies.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildPharmacyCard(_pharmacies[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // Pharmacy card matching exact design
  // ──────────────────────────────────────────

  Widget _buildPharmacyCard(Pharmacy pharmacy) {
    final distance = _getDistance(pharmacy);
    final hasPhone = pharmacy.telephone?.trim().isNotEmpty == true;
    final hasWhatsApp = _primaryWhatsAppNumber(pharmacy) != null;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _N.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _N.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pharmacy name
          Text(
            pharmacy.nom,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _N.textH1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Badge À CONFIRMER + distance
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _N.accent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'À CONFIRMER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (distance != null)
                Text(
                  _formatDistance(distance),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _N.textBody,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Appeler + Itinéraire row
          Row(
            children: [
              // Appeler button
              Expanded(
                child: GestureDetector(
                  onTap: hasPhone
                      ? () => _makePhoneCall(pharmacy.telephone!)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _N.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _N.border,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone,
                            size: 15,
                            color: hasPhone
                                ? _N.textBody
                                : _N.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Appeler',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: hasPhone ? _N.textBody : _N.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Itinéraire button
              Expanded(
                child: GestureDetector(
                  onTap: pharmacy.localisation != null
                      ? () => _openItineraire(pharmacy)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _N.primarySurf,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _N.primary.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation,
                            size: 15, color: _N.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Itinéraire',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _N.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // WhatsApp button (full width, green)
          GestureDetector(
            onTap: hasWhatsApp
                ? () => _openWhatsAppAvailability(pharmacy)
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: hasWhatsApp ? _N.whatsapp : _N.neutralSurf,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(FontAwesomeIcons.whatsapp,
                      size: 17, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'WhatsApp',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
