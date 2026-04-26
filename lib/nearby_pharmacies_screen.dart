import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyPharmaciesScreen extends StatefulWidget {
  const NearbyPharmaciesScreen({super.key});

  @override
  State<NearbyPharmaciesScreen> createState() => _NearbyPharmaciesScreenState();
}

class _NearbyPharmaciesScreenState extends State<NearbyPharmaciesScreen> {
  final PharmacyService _pharmacyService = PharmacyService();
  final LocationService _locationService = LocationService();

  List<Pharmacy> _pharmacies = [];
  bool _isLoading = true;
  String? _error;
  dynamic _userLocation;

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

        final pharmacies = await _pharmacyService.fetchNearbyPharmacies(
          latitude: (location as dynamic).latitude as double,
          longitude: (location as dynamic).longitude as double,
        );

        // Tri local par distance pour garantir "les plus proches"
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
    }  Future<void> _makePhoneCall(String phoneNumber) async {
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

  Future<void> _openWhatsApp(String phoneNumber) async {
    // Nettoyer le numéro (enlever espaces, tirets, parenthèses)
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // S'assurer que le numéro commence par le code pays (237 pour le Cameroun)
    if (!cleanNumber.startsWith('237') && cleanNumber.length == 9) {
      cleanNumber = '237$cleanNumber';
    }

    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanNumber');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp.')),
        );
      }
    }
  }

  Future<void> _openMap(Pharmacy pharmacy) async {
    final point = pharmacy.localisation;
    if (point == null) return;

    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}&travelmode=driving',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacies Proches'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadPharmacies,
        backgroundColor: Colors.green,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadPharmacies,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pharmacies.isEmpty) {
      return const Center(child: Text('Aucune pharmacie trouvée à proximité.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pharmacies.length,
      itemBuilder: (context, index) {
        final pharmacy = _pharmacies[index];
        final distance = _userLocation != null && pharmacy.localisation != null
            ? GeoUtils.haversineDistance(
                startLat: (_userLocation as dynamic).latitude as double,
                startLng: (_userLocation as dynamic).longitude as double,
                endLat: pharmacy.localisation!.latitude,
                endLng: pharmacy.localisation!.longitude,
              )
            : null;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_pharmacy,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pharmacy.nom,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (distance != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.navigation,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDistance(distance),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pharmacy.horaires == 'Ouvert'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pharmacy.horaires ?? 'Horaires inconnus',
                        style: TextStyle(
                          color: pharmacy.horaires == 'Ouvert'
                              ? Colors.green
                              : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pharmacy.adresse ?? 'Adresse non disponible',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (pharmacy.telephone != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pharmacy.telephone!,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Bouton Itinéraire
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openMap(pharmacy),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Itinéraire'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    
                    // Icône WhatsApp
                    if ((pharmacy.whatsapp ?? pharmacy.telephone) != null) ...[
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green, width: 1.5),
                        ),
                        child: IconButton(
                          onPressed: () => _openWhatsApp(
                            pharmacy.whatsapp ?? pharmacy.telephone!,
                          ),
                          icon: const FaIcon(FontAwesomeIcons.whatsapp),
                          color: Colors.green,
                          iconSize: 24,
                          tooltip: 'WhatsApp',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}