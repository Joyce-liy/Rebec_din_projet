import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:http/http.dart' as http;

class PharmacyService {
  static const int nearbyRadiusMeters = 5000;
  static const int nearbyPharmacyLimit = 5;

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

  /// Recherche simple dans le catalogue local (sans filtre géographique).
  /// Retourne uniquement les médicaments qui existent réellement en base.
  Future<List<MedicationCatalogEntry>> searchMedication(String query) async {
    final catalog = await fetchCatalog();
    final lower = query.toLowerCase().trim();

    if (lower.isEmpty) {
      return catalog;
    }

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
    int radius = nearbyRadiusMeters,
    int limit = nearbyPharmacyLimit,
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

    if (limit <= 0) {
      return withinRadius;
    }
    return withinRadius.take(limit).toList();
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

  /// Recherche en temps réel des médicaments dans les pharmacies proches.
  ///
  /// Règles :
  /// - Requête vide ou 1 caractère → liste vide (évite les faux positifs).
  /// - 2+ caractères → recherche dans les stocks Firestore réels.
  /// - Les pharmacies sans GPS sont incluses (elles ont peut-être le médicament).
  /// - Si aucune pharmacie proche géolocalisée, fallback sur toute la base.
  /// - Aucune fausse entrée "A confirmer" générée.
  Future<List<MedicationCatalogEntry>> searchMedicationRealTime(
    String query, {
    required double latitude,
    required double longitude,
    int radius = nearbyRadiusMeters,
  }) async {
    final cleanQuery = query.trim();

    // 1 seul caractère ou vide → pas de résultat pour éviter les faux positifs
    if (cleanQuery.length < 2) {
      return [];
    }

    final allFirestorePharmacies = await fetchPharmacies();

    // Pharmacies avec coordonnées GPS → filtrées par rayon
    final pharmaciesWithLocation =
        allFirestorePharmacies.where((p) => p.localisation != null).toList();

    final nearbyGeolocated = _sortByDistance(
      pharmaciesWithLocation,
      latitude: latitude,
      longitude: longitude,
    ).where((pharmacy) {
      final point = pharmacy.localisation!;
      final distance = _calculateDistance(
        latitude,
        longitude,
        point.latitude,
        point.longitude,
      );
      return distance <= radius;
    }).take(nearbyPharmacyLimit).toList();

    // Pharmacies sans GPS → toujours incluses (stocks réels mais non géolocalisées)
    final pharmaciesWithoutLocation =
        allFirestorePharmacies.where((p) => p.localisation == null).toList();

    // Si aucune pharmacie proche géolocalisée, on cherche dans toute la base
    final List<Pharmacy> pharmaciesToSearch = nearbyGeolocated.isNotEmpty
        ? [...nearbyGeolocated, ...pharmaciesWithoutLocation]
        : allFirestorePharmacies;

    if (pharmaciesToSearch.isEmpty) {
      return [];
    }

    final Map<String, _CatalogAccumulator> accumulator = {};

    for (final pharmacy in pharmaciesToSearch) {
      for (final medication in pharmacy.medicaments) {
        final normalizedName   = _normalize(medication.nom);
        final normalizedDosage = _normalize(medication.dosage);
        final normalizedQuery  = _normalize(cleanQuery);

        // Correspondance : contient la query entière OU tous les mots de la query
        final bool matches = normalizedName.contains(normalizedQuery) ||
            normalizedDosage.contains(normalizedQuery) ||
            normalizedQuery.split(' ').where((w) => w.isNotEmpty).every(
                  (word) =>
                      normalizedName.contains(word) ||
                      normalizedDosage.contains(word),
                );

        if (!matches) continue;

        final String key = medication.id.isNotEmpty
            ? medication.id
            : '${medication.nom}_${medication.dosage}'.toLowerCase();

        accumulator
            .putIfAbsent(
              key,
              () => _CatalogAccumulator(
                id: medication.id.isNotEmpty ? medication.id : key,
                nom: medication.nom,
                dosage: medication.dosage,
              ),
            )
            .availabilities
            .add(MedicationAvailability(
              pharmacy: pharmacy,
              medication: medication,
            ));
      }
    }

    if (accumulator.isEmpty) {
      return [];
    }

    return accumulator.values
        .map((e) => e.toEntry())
        .toList()
      ..sort((a, b) => a.nom.compareTo(b.nom));
  }

  /// Normalise une chaîne pour la comparaison : minuscules + suppression des accents.
  String _normalize(String input) {
    const withAccents    = 'àáâãäåæçèéêëìíîïðñòóôõöùúûüýÿ';
    const withoutAccents = 'aaaaaaaceeeeiiiiðnoooooouuuuyy';
    var result = input.toLowerCase().trim();
    for (var i = 0; i < withAccents.length; i++) {
      result = result.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return result;
  }

  /// Recherche plusieurs médicaments en une seule passe et retourne
  /// les résultats groupés par pharmacie.
  ///
  /// Exemple d'utilisation :
  ///   final results = await searchMultipleMedications(
  ///     ['Paracetamol', 'Amoxicilline'],
  ///     latitude: lat,
  ///     longitude: lng,
  ///   );
  ///   // results est une Map<Pharmacy, List<MedicationAvailability>>
  Future<PharmacySearchResult> searchMultipleMedications(
    List<String> queries, {
    required double latitude,
    required double longitude,
    int radius = nearbyRadiusMeters,
  }) async {
    final cleanQueries = queries
        .map((q) => q.trim())
        .where((q) => q.length >= 2)
        .toList();

    if (cleanQueries.isEmpty) {
      return PharmacySearchResult(
        byMedication: [],
        byPharmacy: {},
        notFound: queries,
      );
    }

    final allFirestorePharmacies = await fetchPharmacies();

    final nearbyPharmacies = _sortByDistance(
      allFirestorePharmacies,
      latitude: latitude,
      longitude: longitude,
    ).where((pharmacy) {
      final point = pharmacy.localisation;
      if (point == null) return false;
      final distance = _calculateDistance(
        latitude,
        longitude,
        point.latitude,
        point.longitude,
      );
      return distance <= radius;
    }).take(nearbyPharmacyLimit).toList();

    // byMedication : pour chaque requête, la liste des pharmacies qui ont ce médicament
    final Map<String, _CatalogAccumulator> byMedicationAcc = {};
    // byPharmacy : pour chaque pharmacie, la liste des médicaments trouvés
    final Map<String, _PharmacyResultAccumulator> byPharmacyAcc = {};
    // Quelles requêtes ont trouvé au moins un résultat
    final Set<String> found = {};

    for (final pharmacy in nearbyPharmacies) {
      for (final medication in pharmacy.medicaments) {
        final lowerName = medication.nom.toLowerCase();
        final lowerDosage = medication.dosage.toLowerCase();

        for (final query in cleanQueries) {
          final lowerQuery = query.toLowerCase();

          if (!lowerName.contains(lowerQuery) &&
              !lowerDosage.contains(lowerQuery)) {
            continue;
          }

          found.add(query);

          // Accumulation par médicament
          final medKey = medication.id.isNotEmpty
              ? medication.id
              : '${medication.nom}_${medication.dosage}'.toLowerCase();

          byMedicationAcc
              .putIfAbsent(
                medKey,
                () => _CatalogAccumulator(
                  id: medication.id.isNotEmpty ? medication.id : medKey,
                  nom: medication.nom,
                  dosage: medication.dosage,
                ),
              )
              .availabilities
              .add(MedicationAvailability(
                pharmacy: pharmacy,
                medication: medication,
              ));

          // Accumulation par pharmacie
          byPharmacyAcc
              .putIfAbsent(
                pharmacy.id,
                () => _PharmacyResultAccumulator(pharmacy: pharmacy),
              )
              .availabilities
              .add(MedicationAvailability(
                pharmacy: pharmacy,
                medication: medication,
              ));
        }
      }
    }

    // Médicaments non trouvés
    final notFound = cleanQueries.where((q) => !found.contains(q)).toList();

    return PharmacySearchResult(
      byMedication: byMedicationAcc.values
          .map((e) => e.toEntry())
          .toList()
        ..sort((a, b) => a.nom.compareTo(b.nom)),
      byPharmacy: {
        for (final acc in byPharmacyAcc.values)
          acc.pharmacy: List.unmodifiable(acc.availabilities),
      },
      notFound: notFound,
    );
  }

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
            localisation: GeoLocationPoint(latitude: eLat, longitude: eLon),
            horaires: null,
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
      final loc = p.localisation;
      final double pLat = loc?.latitude ?? 0.0;
      final double pLng = loc?.longitude ?? 0.0;

      final key = '${p.nom}_${pLat}_$pLng';
      if (!map.containsKey(key)) map[key] = p;
    }

    return map.values.toList();
  }
}

// ---------------------------------------------------------------------------
// Modèle de résultat pour la recherche multi-médicaments
// ---------------------------------------------------------------------------

/// Résultat complet d'une recherche multi-médicaments.
///
/// [byMedication] : liste de [MedicationCatalogEntry], chacune contenant
///   toutes les pharmacies proches qui proposent ce médicament avec son prix
///   et sa disponibilité.
///
/// [byPharmacy] : vue inversée — pour chaque pharmacie, tous les médicaments
///   correspondants avec prix et disponibilité.
///
/// [notFound] : noms des médicaments pour lesquels aucune pharmacie n'a de
///   stock dans le rayon donné.
class PharmacySearchResult {
  const PharmacySearchResult({
    required this.byMedication,
    required this.byPharmacy,
    required this.notFound,
  });

  final List<MedicationCatalogEntry> byMedication;
  final Map<Pharmacy, List<MedicationAvailability>> byPharmacy;
  final List<String> notFound;

  bool get isEmpty => byMedication.isEmpty;
  bool get isNotEmpty => byMedication.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Accumulateurs internes
// ---------------------------------------------------------------------------

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

class _PharmacyResultAccumulator {
  _PharmacyResultAccumulator({required this.pharmacy});

  final Pharmacy pharmacy;
  final List<MedicationAvailability> availabilities = [];
}