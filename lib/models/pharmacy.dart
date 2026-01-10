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

class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.nom,
    required this.quartier,
    required this.latitude,
    required this.longitude,
    required this.telephone,
    required this.horaires,
    required this.medicaments,
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    final medicationsJson = json['medicaments'] as List<dynamic>? ?? [];
    return Pharmacy(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      quartier: json['quartier'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      telephone: json['telephone'] as String? ?? '',
      horaires: json['horaires'] as String? ?? '',
      medicaments: medicationsJson
          .map((item) => PharmacyMedication.fromJson(
              item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String nom;
  final String quartier;
  final double latitude;
  final double longitude;
  final String telephone;
  final String horaires;
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
