import 'dart:convert';
import 'dart:math'; // Nécessaire pour le calcul de distance (sqrt, asin)
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:pharma/models/pharmacy.dart';

class PharmacyService {
  // Plus besoin de Google API Key ici

  PharmacyService._internal();

  static final PharmacyService _instance = PharmacyService._internal();

  factory PharmacyService() => _instance;

  List<Pharmacy>? _pharmacies;
  List<MedicationCatalogEntry>? _catalog;

  // --- 1. GESTION DU FICHIER LOCAL (Si tu gardes un catalogue offline) ---
  Future<List<Pharmacy>> fetchPharmacies() async {
    // Si tu as besoin de charger tes données JSON locales, garde cette partie.
    // Sinon, elle retourne une liste vide par défaut.
    if (_pharmacies != null) {
      return _pharmacies!;
    }

    // Simule un chargement ou charge ton fichier JSON existant si besoin
    // final String jsonString = await rootBundle.loadString('assets/pharmacies_data.json');
    // final Map<String, dynamic> data = json.decode(jsonString) as Map<String, dynamic>;
    // ...
    
    _pharmacies = []; 
    return _pharmacies!;
  }

  Future<List<MedicationCatalogEntry>> fetchCatalog() async {
    // Cette méthode sert à créer un index de médicaments à partir de tes pharmacies.
    // Important : Les pharmacies d'OpenStreetMap n'ont PAS de stock de médicaments.
    // Donc ce catalogue sera vide à moins que tu ne mélanges avec des données locales.
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

  // --- 2. FONCTION UTILITAIRE DE CALCUL DE DISTANCE (HAVERSINE) ---
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Pi / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // Résultat en mètres
  }

  // --- 3. MÉTHODE PRINCIPALE : RECUPERER LES 5 PLUS PROCHES (OPENSTREETMAP) ---
  Future<List<Pharmacy>> fetchNearbyPharmacies({
    required double latitude,
    required double longitude,
    int radius = 5000, // Rayon de recherche en mètres (5km)
  }) async {
    // Requête Overpass QL pour OpenStreetMap
    final String query = '''
      [out:json][timeout:30];
      (
        node["amenity"="pharmacy"](around:$radius,$latitude,$longitude);
        way["amenity"="pharmacy"](around:$radius,$latitude,$longitude);
      );
      out body center;
    ''';

    final String url = 'https://overpass-api.de/api/interpreter';

    print('DEBUG: Appel API OpenStreetMap...');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
          'User-Agent': 'PharmaApp/1.0 (Flutter; Android)',
        },
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(
        const Duration(seconds: 40),
        onTimeout: () {
          throw Exception('Timeout API Overpass - La requête a dépassé 40 secondes');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>;

        print('DEBUG: ${elements.length} pharmacies trouvées dans la zone.');

        // Étape A : Préparer une liste temporaire pour le tri
        final List<Map<String, dynamic>> tempResults = [];

        for (var element in elements) {
          // Récupérer les coordonnées (peuvent être directes ou dans 'center')
          final lat = element['lat'] ?? element['center']['lat'];
          final lon = element['lon'] ?? element['center']['lon'];
          final tags = element['tags'] as Map<String, dynamic>?;

          if (lat == null || lon == null) continue;

          // Calculer la distance par rapport à l'utilisateur
          final distanceMeters = _calculateDistance(latitude, longitude, lat, lon);

          tempResults.add({
            'distance': distanceMeters,
            'lat': lat,
            'lon': lon,
            'element': element,
          });
        }

        // Étape B : Trier par distance croissante (le plus petit d'abord)
        tempResults.sort((a, b) => a['distance'].compareTo(b['distance']));

        // Étape C : Ne garder que les 5 premiers
        final top5 = tempResults.take(5).toList();

        // Étape D : Construire les objets Pharmacy finaux
        final List<Pharmacy> pharmacies = [];

        for (var item in top5) {
          final element = item['element'];
          final tags = element['tags'] as Map<String, dynamic>?;
          
          final name = tags?['name'] ?? 'Pharmacie';
          
          // Construction de l'adresse
          final street = tags?['addr:street'] ?? '';
          final city = tags?['addr:city'] ?? '';
          final address = street.isNotEmpty ? '$street, $city' : 'Adresse non disponible';
          
          // OpenStreetMap fournit rarement le téléphone
          final phone = tags?['phone'] ?? tags?['contact:phone'];

          pharmacies.add(
            Pharmacy(
              id: element['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              nom: name,
              adresse: address,
              telephone: phone,
              whatsapp: null,
              localisation: GeoLocationPoint(latitude: item['lat'] as double, longitude: item['lon'] as double),
              horaires: tags?['opening_hours'] ?? 'Horaires inconnus',
              medicaments: [],
            ),
          );
        }

        return pharmacies;
      } else {
        print('Erreur API OSM: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception: $e');
      return [];
    }
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

  // --- 4. RECHERCHE MEDICAMENT TEMPS REEL (Simulé via OSM) ---
  Future<List<MedicationCatalogEntry>> searchMedicationRealTime(
    String query, {
    required double latitude,
    required double longitude,
    int radius = 5000,
  }) async {
    // 1. Récupérer les pharmacies proches via OSM
    final pharmacies = await fetchNearbyPharmacies(
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    );

    if (pharmacies.isEmpty) {
      return [];
    }

    // 2. Créer une entrée de catalogue pour le médicament recherché
    // Note: Comme OSM ne donne pas le stock, on "simule" que les pharmacies trouvées
    // ont potentiellement le médicament (StockStatus.enStock ou unknown).
    // Tu pourrais ici randomiser ou mettre "Stock Limité" pour faire plus réaliste,
    // ou simplement afficher que la pharmacie est ouverte.

    final String cleanQuery = query.trim();
    
    // Créer les disponibilités
    final List<MedicationAvailability> availabilities = pharmacies.map((pharmacy) {
      // On crée un médicament "fictif" correspondant à la recherche dans chaque pharmacie
      final med = PharmacyMedication(
        id: '${cleanQuery}_${pharmacy.id}',
        nom: cleanQuery,
        dosage: 'Standard', // On ne connait pas le dosage via OSM
        status: StockStatus.enStock, // On assume qu'elles l'ont
        quantite: 10, // Valeur fictive
        prix: 0.0, // Prix inconnu
        lastUpdate: DateTime.now(),
      );
      
      // On l'ajoute à la pharmacie (optionnel, selon ta structure)
       pharmacy.medicaments.add(med);

      return MedicationAvailability(
        pharmacy: pharmacy,
        medication: med,
      );
    }).toList();

    // Retourner l'entrée du catalogue
    final entry = MedicationCatalogEntry(
      id: 'search_$cleanQuery',
      nom: cleanQuery,
      dosage: 'Standard',
      availabilities: availabilities,
    );

    return [entry];
  }
}

// --- Classes utilitaires pour le catalogue (inchangées) ---

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