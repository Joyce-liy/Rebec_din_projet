import 'package:collection/collection.dart';

enum StockStatus {
  enStock('en_stock'),
  stockLimite('stock_limite'),
  rupture('rupture'),
  aConfirmer('a_confirmer');

  const StockStatus(this.jsonValue);

  final String jsonValue;

  static StockStatus fromJson(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unknown') {
      return StockStatus.aConfirmer;
    }
    return StockStatus.values.firstWhere(
      (status) => status.jsonValue == normalized,
      orElse: () => StockStatus.aConfirmer,
    );
  }

  String get label {
    switch (this) {
      case StockStatus.enStock:
        return 'En stock';
      case StockStatus.stockLimite:
        return 'Stock limité';
      case StockStatus.rupture:
        return 'Rupture';
      case StockStatus.aConfirmer:
        return 'A confirmer';
    }
  }
}

class PharmacyMedication {
  const PharmacyMedication({
    required this.id,
    required this.nom,
    required this.dosage,
    required this.status,
    required this.quantite,
    required this.prix,
    required this.lastUpdate,
  });

  factory PharmacyMedication.fromJson(Map<String, dynamic> json) {
    return PharmacyMedication(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      status: StockStatus.fromJson(json['statut'] as String? ?? ''),
      quantite: (json['quantite'] as num?)?.toInt() ?? 0,
      prix: (json['prix'] as num?)?.toDouble() ?? 0,
      lastUpdate: DateTime.tryParse(json['last_update'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String nom;
  final String dosage;
  final StockStatus status;
  final int quantite;
  final double prix;
  final DateTime lastUpdate;
}

class GeoLocationPoint {
  const GeoLocationPoint({
    required this.latitude,
    required this.longitude,
  });

  factory GeoLocationPoint.fromJson(Map<String, dynamic> json) {
    final directLatitude = json['latitude'] ?? json['lat'];
    final directLongitude = json['longitude'] ?? json['lng'] ?? json['lon'];
    if (directLatitude is num && directLongitude is num) {
      return GeoLocationPoint(
        latitude: directLatitude.toDouble(),
        longitude: directLongitude.toDouble(),
      );
    }

    final List<dynamic> coordinates =
        (json['coordinates'] as List<dynamic>?) ?? const [];
    final double longitude = coordinates.isNotEmpty
        ? (coordinates[0] as num?)?.toDouble() ?? 0
        : 0;
    final double latitude = coordinates.length > 1
        ? (coordinates[1] as num?)?.toDouble() ?? 0
        : 0;
    return GeoLocationPoint(latitude: latitude, longitude: longitude);
  }

  static GeoLocationPoint? tryParse(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is GeoLocationPoint) {
      return value;
    }
    if (value is Map<String, dynamic>) {
      return GeoLocationPoint.fromJson(value);
    }
    if (value is Map) {
      return GeoLocationPoint.fromJson(Map<String, dynamic>.from(value));
    }

    try {
      final dynamic dynamicValue = value;
      final latitude = dynamicValue.latitude;
      final longitude = dynamicValue.longitude;
      if (latitude is num && longitude is num) {
        return GeoLocationPoint(
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  final double latitude;
  final double longitude;
}

class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.nom,
    required this.adresse,
    required this.telephone,
    required this.whatsapp,
    required this.localisation,
    required this.horaires,
    required this.medicaments,
    this.source = 'firestore',
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    final medicationsJson =
        (json['medicaments'] ?? json['medications']) as List<dynamic>? ?? [];
    return Pharmacy(
      id: _parseId(json['id']),
      nom: _parseNullableString(json['nom'] ?? json['name']) ?? '',
      adresse: _parseNullableString(json['adresse'] ?? json['address']),
      telephone: _parseNullableString(json['telephone'] ?? json['phone']),
      whatsapp: _parseNullableString(json['whatsapp']),
      localisation: GeoLocationPoint.tryParse(
        json['localisation'] ?? json['location'],
      ),
      horaires: _parseNullableString(json['horaires']) ??
          (json['is_active'] == false ? 'Fermee' : 'Ouvert'),
      medicaments: medicationsJson
          .whereType<Map>()
          .map((item) => PharmacyMedication.fromJson(
              Map<String, dynamic>.from(item)))
          .toList(),
      source: json['source'] as String? ?? 'firestore',
    );
  }

  static String _parseId(dynamic value) {
    return value?.toString() ?? '';
  }

  static String? _parseNullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  final String id;
  final String nom;
  final String? adresse;
  final String? telephone;
  final String? whatsapp;
  final GeoLocationPoint? localisation;
  final String? horaires;
  final List<PharmacyMedication> medicaments;
  final String source; // 'firestore' or 'osm'

  PharmacyMedication? medicationById(String id) =>
      medicaments.firstWhereOrNull((med) => med.id == id);

  PharmacyMedication? medicationByName(String name) => medicaments
      .firstWhereOrNull((med) => med.nom.toLowerCase() == name.toLowerCase());
}

class MedicationAvailability {
  const MedicationAvailability({
    required this.pharmacy,
    required this.medication,
  });

  final Pharmacy pharmacy;
  final PharmacyMedication medication;
}

class MedicationCatalogEntry {
  const MedicationCatalogEntry({
    required this.id,
    required this.nom,
    required this.dosage,
    required this.availabilities,
  });

  final String id;
  final String nom;
  final String dosage;
  final List<MedicationAvailability> availabilities;
}
