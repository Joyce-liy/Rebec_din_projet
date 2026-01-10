import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pharma/models/pharmacy.dart';

class PharmacyService {
  PharmacyService._internal();

  static final PharmacyService _instance = PharmacyService._internal();

  factory PharmacyService() => _instance;

  List<Pharmacy>? _pharmacies;
  List<MedicationCatalogEntry>? _catalog;

  Future<List<Pharmacy>> fetchPharmacies() async {
    if (_pharmacies != null) {
      return _pharmacies!;
    }

    final String jsonString =
        await rootBundle.loadString('assets/pharmacies_data.json');
    final Map<String, dynamic> data = json.decode(jsonString) as Map<String, dynamic>;
    final List<dynamic> pharmaciesJson = data['pharmacies'] as List<dynamic>? ?? [];

    _pharmacies = pharmaciesJson
        .map((item) => Pharmacy.fromJson(item as Map<String, dynamic>))
        .toList();
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
