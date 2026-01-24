import 'package:flutter/material.dart';
import 'package:pharma/profil.dart';
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
import 'package:permission_handler/permission_handler.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}
class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin{
  static const double _radiusMeters = 5000;
  late stt.SpeechToText _speech;
  late AnimationController _animationController;
  Timer? _silenceTimer;
  bool _isListening = false;
  //bool _isListening = false;
  final PharmacyService _pharmacyService = PharmacyService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
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

    // --- RECHERCHE TEMPS REEL VIA OSM ---
    if (_userLocation != null) {
       setState(() {
         // Optionnel : Afficher un loading spécifique si besoin
       });
       
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
         // Fallback sur le catalogue local si erreur
         _fallbackLocalFilter(query);
       }
    } else {
      // Pas de localisation, recherche locale uniquement
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
    return StockStatus.rupture;
  }

  Color _statusColor(StockStatus? status) {
    switch (status) {
      case StockStatus.enStock:
        return Colors.green;
      case StockStatus.stockLimite:
        return Colors.orange;
      case StockStatus.rupture:
        return Colors.red;
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
      MedicationCatalogEntry entry) {
    final List<MedicationAvailability> availabilities =
        List<MedicationAvailability>.from(entry.availabilities);
    if (_userLocation == null) {
      return availabilities;
    }
    final GeoPoint location = _userLocation!;
    final List<MedicationAvailability> filtered = availabilities
        .where((availability) {
      final point = availability.pharmacy.localisation;
      if (point == null) {
        return false;
      }
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
          const SnackBar(content: Text('Localisation indisponible pour cette pharmacie.')),
        );
      }
      return;
    }
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}&travelmode=driving',
    );
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir l'itineraire.")),
      );
    }
  }

  Widget _buildStatusBadge(StockStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
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
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBanner() {
    if (_loadingLocation) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Localisation en cours...')),
          ],
        ),
      );
    }

    if (_userLocation != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.my_location, color: Colors.green),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Localisation activee pour un tri par distance.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.green),
              tooltip: 'Rafraichir la position',
              onPressed: _refreshLocation,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _locationUnavailable
                  ? 'Localisation indisponible. Autorisez l\'acces GPS pour trier les pharmacies par distance.'
                  : 'Activez votre localisation pour un tri par distance.',
            ),
          ),
          TextButton(onPressed: _refreshLocation, child: const Text('Activer')),
        ],
      ),
    );
  }

  Widget _buildAvailabilityTiles(
    MedicationCatalogEntry entry,
    List<MedicationAvailability> availabilities,
  ) {
    if (availabilities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text('Aucune officine n\'a ete trouvee dans un rayon de 5 km.'),
      );
    }

    return Column(
      children: availabilities.asMap().entries.map((mapEntry) {
        final index = mapEntry.key;
        final availability = mapEntry.value;
        final pharmacy = availability.pharmacy;
        final medication = availability.medication;
        final distance = _distanceToPharmacy(pharmacy);
        
        // Animation simple d'apparition glissée
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          duration: Duration(milliseconds: 400 + (index * 100)),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.business, color: Colors.green.shade700, size: 24),
            ),
            title: Text(
              pharmacy.nom,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  pharmacy.adresse ?? 'Adresse indisponible',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Badge "Ouvert" ou Horaire si dispo via OSM (souvent brut)
                    /* 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text("Disponible", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    */
                    
                    if (distance != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDistance(distance),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600, 
                              color: Colors.black87,
                              fontSize: 13
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: () => _openDirections(pharmacy),
                          icon: const Icon(Icons.directions, size: 16),
                          label: const Text('Y aller', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ),
                    if (pharmacy.telephone != null) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () => launchUrl(Uri.parse('tel:${pharmacy.telephone}')),
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text('Appeler', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
                const Divider(height: 24),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults() {
    if (_filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(child: Text('Aucun medicament trouve')),
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
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            title: Text(
              entry.nom,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${entry.dosage} • ${availabilities.length} pharmacies dans 5 km',
            ),
            children: [
              // --- NOTE D'AVERTISSEMENT STOCK ---
              if (_userLocation != null && availabilities.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.orange.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Disponibilité estimée basée sur la proximité.\nContactez l'officine pour confirmer le stock.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // -----------------------------------

              if (_userLocation == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Activez la localisation pour filtrer les officines proches. Affichage de toutes les pharmacies disponibles.',
                  ),
                ),
              if (_userLocation != null && availabilities.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Aucune pharmacie dans un rayon de 5 km. Affichez la carte pour explorer.',
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
                  child: ElevatedButton.icon(
                    onPressed: () => _openMap(entry),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Afficher sur la carte'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
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
          return const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Aucune recherche recente',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = history[index];
            final parts = entry.split(':');
            final source = parts.isNotEmpty ? parts.first : 'Recherche';
            final term = parts.length > 1 ? parts.sublist(1).join(':') : entry;

            final IconData icon =
                source == 'Scanner' ? Icons.document_scanner_outlined : Icons.history;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: Icon(icon, color: Colors.green),
              title: Text(term),
              subtitle: Text(source),
              onTap: () => _onRecentSearchSelected(term),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => HistoryService.instance.remove(entry),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle,
              color: Colors.black,
              size: 30,
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
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
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'La Recherche',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLocationBanner(),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Bonjour, quel medicament recherchez-vous?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                                      Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onQueryChanged,
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              HistoryService.instance.add(value);
                              _applyFilter(value);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Rechercher un medicament',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.green,
                              size: 30,
                            ),
                            suffixIcon: _isSearching
                                ? IconButton(
                                    onPressed: _clearSearch,
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.grey,
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // --- BOUTON DYNAMIQUE (VOCAL OU ENVOYER) ---
                      GestureDetector(
                        onTap: () {
                          if (_searchController.text.trim().isNotEmpty) {
                            // Action ENVOYER
                            HistoryService.instance.add(_searchController.text);
                            _applyFilter(_searchController.text);
                            FocusScope.of(context).unfocus(); // Ferme le clavier
                          } else {
                            // Action VOCAL
                            _listen();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            // Change de couleur : Rouge si écoute, Bleu si texte présent, Vert sinon
                            color: _isListening 
                                ? Colors.red 
                                : (_searchController.text.isNotEmpty ? Colors.green : Colors.green),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            // Change d'icône : Stop si écoute, Send si texte présent, Mic sinon
                            _isListening 
                                ? Icons.stop 
                                : (_searchController.text.isNotEmpty ? Icons.send : Icons.mic),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ScannerPage()),
                          );
                        },
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                        label: const Text('Scanner une ordonnance',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _isSearching
                          ? 'Resultats trouves'
                          : 'Historique des recherches recentes',
                      style: const TextStyle(color: Colors.black87, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    _isSearching
                        ? _buildSearchResults()
                        : Column(
                            children: [
                              _buildHistoryList(),
                              const SizedBox(height: 30),
                              const Text(
                                'Medicaments disponibles',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
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