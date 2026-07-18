import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:http/http.dart' as http;

class PharmacyService {
  final LocationService _locationService = LocationService();

  PharmacyService._internal();

  static final PharmacyService _instance = PharmacyService._internal();

  factory PharmacyService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Pharmacy>? _pharmacies;
  List<MedicationCatalogEntry>? _catalog;

  Future<List<Pharmacy>> fetchPharmacies() async {
    if (_pharmacies != null) {
      return _pharmacies!;
    }

    try {
      final snapshot = await _firestore.collection('pharmacies').get();
      _pharmacies = snapshot.docs
          .where((doc) => doc.data()['is_active'] != false)
          .map((doc) => Pharmacy.fromJson({
                ...doc.data(),
                'id': doc.id,
              }))
          .where((pharmacy) => pharmacy.nom.trim().isNotEmpty)
          .toList();
    } catch (e) {
      print('Erreur Firestore pharmacies: $e');
      _pharmacies = [];
    }

    return _pharmacies!;
  }

  Future<List<MedicationCatalogEntry>> fetchCatalog() async {
    if (_catalog != null) {
      return _catalog!;
    }

    final pharmacies = await fetchPharmacies();
    final Map<String, _CatalogAccumulator> accumulator = {};

    for (final pharmacy in pharmacies) {
      for (final medication in pharmacy.medicaments) {
        final String key = medication.id.isNotEmpty
            ? medication.id
            : '${medication.nom}_${medication.dosage}'.toLowerCase();

        final accumulatorEntry = accumulator.putIfAbsent(
          key,
          () => _CatalogAccumulator(
            id: medication.id.isNotEmpty ? medication.id : key,
            nom: medication.nom,
            dosage: medication.dosage,
          ),
        );

        accumulatorEntry.availabilities.add(
          MedicationAvailability(
            pharmacy: pharmacy,
            medication: medication,
          ),
        );
      }
    }

    _catalog = accumulator.values
        .map((entry) => entry.toEntry())
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));

    return _catalog!;
  }

  Future<void> invalidateCache() async {
    _pharmacies = null;
    _catalog = null;
  }

  Future<List<MedicationCatalogEntry>> searchMedication(String query) async {
    final catalog = await fetchCatalog();
    if (query.isEmpty) {
      return catalog;
    }

    final lower = query.toLowerCase();
    return catalog
        .where((entry) =>
            entry.nom.toLowerCase().contains(lower) ||
            entry.dosage.toLowerCase().contains(lower))
        .toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  List<Pharmacy> _sortByDistance(
    List<Pharmacy> pharmacies, {
    required double latitude,
    required double longitude,
  }) {
    final sorted = pharmacies
        .where((pharmacy) => pharmacy.localisation != null)
        .toList();

    sorted.sort((a, b) {
      final pointA = a.localisation!;
      final pointB = b.localisation!;
      final distanceA = _calculateDistance(
        latitude,
        longitude,
        pointA.latitude,
        pointA.longitude,
      );
      final distanceB = _calculateDistance(
        latitude,
        longitude,
        pointB.latitude,
        pointB.longitude,
      );
      return distanceA.compareTo(distanceB);
    });

    return sorted;
  }

  /// Récupère les pharmacies depuis OpenStreetMap via Overpass API
  Future<List<Pharmacy>> _fetchOsmPharmacies({
    required double latitude,
    required double longitude,
    int radius = 5000,
  }) async {
    final query = '''
[out:json][timeout:10];
(
  node["amenity"="pharmacy"](around:$radius,$latitude,$longitude);
  way["amenity"="pharmacy"](around:$radius,$latitude,$longitude);
);
out center;
''';

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': query},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('Overpass API erreur: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>? ?? [];

      return elements.map<Pharmacy?>((element) {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        final String nom = (tags['name'] as String?) ??
            (tags['name:fr'] as String?) ??
            'Pharmacie';

        if (nom.trim().isEmpty) return null;

        double? lat;
        double? lon;

        if (element['type'] == 'node') {
          lat = (element['lat'] as num?)?.toDouble();
          lon = (element['lon'] as num?)?.toDouble();
        } else {
          // For ways, use the center coordinates
          final center = element['center'] as Map<String, dynamic>?;
          lat = (center?['lat'] as num?)?.toDouble();
          lon = (center?['lon'] as num?)?.toDouble();
        }

        if (lat == null || lon == null) return null;

        final String? phone = tags['phone'] as String? ??
            tags['contact:phone'] as String?;
        final String? website = tags['website'] as String?;

        return Pharmacy(
          id: 'osm_${element['id']}',
          nom: nom,
          adresse: _buildOsmAddress(tags),
          telephone: phone,
          whatsapp: null,
          localisation: GeoLocationPoint(latitude: lat, longitude: lon),
          horaires: _parseOsmOpeningHours(tags),
          medicaments: const [],
          source: 'osm',
        );
      }).whereType<Pharmacy>().toList();
    } catch (e) {
      print('Erreur Overpass API: $e');
      return [];
    }
  }

  String? _buildOsmAddress(Map<String, dynamic> tags) {
    final parts = <String>[];
    if (tags['addr:street'] != null) {
      if (tags['addr:housenumber'] != null) {
        parts.add('${tags['addr:housenumber']} ${tags['addr:street']}');
      } else {
        parts.add(tags['addr:street'] as String);
      }
    }
    if (tags['addr:city'] != null) {
      parts.add(tags['addr:city'] as String);
    }
    if (tags['addr:quarter'] != null && parts.isEmpty) {
      parts.add(tags['addr:quarter'] as String);
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  String? _parseOsmOpeningHours(Map<String, dynamic> tags) {
    final hours = tags['opening_hours'] as String?;
    if (hours == null) return null;
    if (hours.contains('24/7')) return 'Ouvert 24h/24';
    return hours.length > 30 ? '${hours.substring(0, 27)}...' : hours;
  }

  /// Déduplique les pharmacies Firestore et OSM (< 50m = même pharmacie).
  /// Garde la version Firestore quand doublon car elle a plus de données.
  List<Pharmacy> _deduplicatePharmacies(
    List<Pharmacy> firestorePharmacies,
    List<Pharmacy> osmPharmacies,
  ) {
    final List<Pharmacy> merged = List.from(firestorePharmacies);

    for (final osmPharmacy in osmPharmacies) {
      final osmPoint = osmPharmacy.localisation;
      if (osmPoint == null) continue;

      bool isDuplicate = false;
      for (final fsPharmacy in firestorePharmacies) {
        final fsPoint = fsPharmacy.localisation;
        if (fsPoint == null) continue;

        final distance = _calculateDistance(
          osmPoint.latitude,
          osmPoint.longitude,
          fsPoint.latitude,
          fsPoint.longitude,
        );

        if (distance < 50) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        merged.add(osmPharmacy);
      }
    }

    return merged;
  }

  Future<List<Pharmacy>> fetchNearbyPharmacies({
    required double latitude,
    required double longitude,
    int radius = 5000,
    int limit = 20,
  }) async {
    final results = await Future.wait([
      fetchPharmacies(),
      _fetchOsmPharmacies(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      ),
    ]);

    final firestorePharmacies = results[0];
    final osmPharmacies = results[1];

    final allPharmacies = _deduplicatePharmacies(
      firestorePharmacies,
      osmPharmacies,
    );

    final sorted = _sortByDistance(
      allPharmacies,
      latitude: latitude,
      longitude: longitude,
    );

    final withinRadius = sorted.where((pharmacy) {
      final point = pharmacy.localisation!;
      final distance = _calculateDistance(
        latitude,
        longitude,
        point.latitude,
        point.longitude,
      );
      return distance <= radius;
    }).toList();

    final finalResults = withinRadius.isNotEmpty ? withinRadius : sorted;
    if (limit <= 0) {
      return finalResults;
    }
    return finalResults.take(limit).toList();
  }

  Future<int?> estimateDrivingTravelTimeSeconds({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$startLongitude,$startLatitude;'
      '$endLongitude,$endLatitude'
      '?overview=false',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return null;
      }

      final first = routes.first as Map<String, dynamic>;
      final duration = first['duration'];
      if (duration is num) {
        return duration.round();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<MedicationCatalogEntry>> searchMedicationRealTime(
    String query, {
    required double latitude,
    required double longitude,
    int radius = 5000,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return [];
    }

    final pharmacies = await fetchNearbyPharmacies(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      limit: 0,
    );

    if (pharmacies.isEmpty) {
      return [];
    }

    final availabilities = pharmacies.map((pharmacy) {
      final medication = _medicationForSearch(pharmacy, cleanQuery);
      return MedicationAvailability(
        pharmacy: pharmacy,
        medication: medication,
      );
    }).toList();

    return [
      MedicationCatalogEntry(
        id: 'firebase_search_${cleanQuery.toLowerCase()}',
        nom: cleanQuery,
        dosage: 'Disponibilite et prix a confirmer',
        availabilities: availabilities,
      ),
    ];
  }

  PharmacyMedication _medicationForSearch(Pharmacy pharmacy, String query) {
    final lowerQuery = query.toLowerCase();
    for (final medication in pharmacy.medicaments) {
      final lowerName = medication.nom.toLowerCase();
      if (lowerName == lowerQuery || lowerName.contains(lowerQuery)) {
        return medication;
      }
    }

    return PharmacyMedication(
      id: '${query.toLowerCase()}_${pharmacy.id}',
      nom: query,
      dosage: 'A confirmer',
      status: StockStatus.aConfirmer,
      quantite: 0,
      prix: 0,
      lastUpdate: DateTime.now(),
    );
  }

  // CORRECTION : paramètre `medicaments` ajouté (liste vide par défaut)
  // et `localisation` reçoit bien un GeoLocationPoint
  Future<List<Pharmacy>> _fetchOverpassNearby(
    double lat,
    double lng, {
    int radius = 5000,
  }) async {
    final url = Uri.parse('https://overpass-api.de/api/interpreter');
    final query =
        '[out:json][timeout:10];(node["amenity"="pharmacy"](around:$radius,$lat,$lng););out body;';
    try {
      final res = await http
          .post(url, body: {'data': query})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final elements = data['elements'] as List<dynamic>? ?? [];
        return elements.map<Pharmacy>((e) {
          final eLat = (e['lat'] as num?)?.toDouble() ?? 0.0;
          final eLon = (e['lon'] as num?)?.toDouble() ?? 0.0;
          return Pharmacy(
            id: 'osm_${e['id']}',
            nom: (e['tags']?['name'])?.toString() ?? 'Pharmacie',
            adresse: (e['tags']?['addr:full'])?.toString() ??
                (e['tags']?['addr:street'])?.toString(),
            telephone: (e['tags']?['phone'])?.toString(),
            whatsapp: null,
            // CORRECTION : GeoLocationPoint au lieu d'une Map brute
            localisation: GeoLocationPoint(latitude: eLat, longitude: eLon),
            horaires: null,
            // CORRECTION : paramètre obligatoire ajouté
            medicaments: const [],
            source: 'osm',
          );
        }).toList();
      } else {
        throw Exception('Overpass status ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Overpass API erreur: $e');
      rethrow;
    }
  }

  Future<List<Pharmacy>> _fetchFirestorePharmacies() async {
    try {
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Pharmacy>> fetchHybridPharmacies({
    required double latitude,
    required double longitude,
    int radius = 5000,
  }) async {
    List<Pharmacy> osm = [];
    try {
      osm = await _fetchOverpassNearby(latitude, longitude, radius: radius);
    } catch (_) {
      osm = [];
    }

    final firestore = await _fetchFirestorePharmacies();

    final Map<String, Pharmacy> map = {};
    for (final p in [...firestore, ...osm]) {
      // CORRECTION : localisation est maintenant toujours un GeoLocationPoint?
      final loc = p.localisation;
      final double pLat = loc?.latitude ?? 0.0;
      final double pLng = loc?.longitude ?? 0.0;

      final key = '${p.nom}_${pLat}_$pLng';
      if (!map.containsKey(key)) map[key] = p;
    }

    return map.values.toList();
  }
}

class _CatalogAccumulator {
  _CatalogAccumulator({
    required this.id,
    required this.nom,
    required this.dosage,
  });

  final String id;
  final String nom;
  final String dosage;
  final List<MedicationAvailability> availabilities = [];

  MedicationCatalogEntry toEntry() {
    return MedicationCatalogEntry(
      id: id,
      nom: nom,
      dosage: dosage,
      availabilities: List.unmodifiable(availabilities),
    );
  }
}