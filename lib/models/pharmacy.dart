import 'package:collection/collection.dart';

enum StockStatus {
  enStock('en_stock'),
  stockLimite('stock_limite'),
  rupture('rupture');

  const StockStatus(this.jsonValue);

  final String jsonValue;

  static StockStatus fromJson(String value) {
    return StockStatus.values.firstWhere(
      (status) => status.jsonValue == value,
      orElse: () => StockStatus.rupture,
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
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    final medicationsJson = json['medicaments'] as List<dynamic>? ?? [];
    final localisationJson = json['localisation'] as Map<String, dynamic>?;
    return Pharmacy(
      id: _parseId(json['id']),
      nom: json['nom'] as String? ?? '',
      adresse: json['adresse'] as String?,
      telephone: json['telephone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      localisation: localisationJson != null
          ? GeoLocationPoint.fromJson(localisationJson)
          : null,
      horaires: json['horaires'] as String?,
      medicaments: medicationsJson
          .map((item) => PharmacyMedication.fromJson(
              item as Map<String, dynamic>))
          .toList(),
    );
  }

  static int _parseId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  final int id;
  final String nom;
  final String? adresse;
  final String? telephone;
  final String? whatsapp;
  final GeoLocationPoint? localisation;
  final String? horaires;
  final List<PharmacyMedication> medicaments;

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
