import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/pharmacy.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Sauvegarder / mettre à jour une pharmacie ──
  Future<String> savePharmacy(
    Pharmacy pharmacy, {
    List<Map<String, dynamic>>? medicaments,
  }) async {
    try {
      final docRef = pharmacy.id.isEmpty
          ? _db.collection('pharmacies').doc()
          : _db.collection('pharmacies').doc(pharmacy.id);

      final data = pharmacy.toFirestore();
      if (medicaments != null) {
        data['medicaments'] = medicaments;
      }

      await docRef.set(data, SetOptions(merge: true));
      return docRef.id;
    } catch (e) {
      debugPrint('Erreur savePharmacy: $e');
      rethrow;
    }
  }

  // ── Import CSV avec fusion (sans doublons) ──
  // Clé d'identification : nom + dosage (insensible à la casse)
  Future<Map<String, int>> importMedications(
    String pharmacyId,
    List<Map<String, dynamic>> newMeds,
  ) async {
    int added = 0;
    int updated = 0;

    try {
      final docRef = _db.collection('pharmacies').doc(pharmacyId);
      final doc = await docRef.get();
      final data = doc.data() ?? <String, dynamic>{};

      final List<dynamic> existing = List.from(data['medicaments'] ?? []);

      // Map existants : clé = nom|dosage
      final Map<String, Map<String, dynamic>> mergeMap = {};
      for (final med in existing) {
        final m = Map<String, dynamic>.from(med as Map);
        mergeMap[_medKey(m)] = m;
      }

      for (final newMed in newMeds) {
        final key = _medKey(newMed);
        if (mergeMap.containsKey(key)) {
          // Écrase l'existant en conservant l'id original si présent
          final existingId = mergeMap[key]!['id'];
          mergeMap[key] = {
            ...mergeMap[key]!,
            ...newMed,
            if (existingId != null && existingId.toString().isNotEmpty)
              'id': existingId,
            'last_update': DateTime.now().toIso8601String(),
          };
          updated++;
        } else {
          mergeMap[key] = {
            ...newMed,
            'last_update': DateTime.now().toIso8601String(),
          };
          added++;
        }
      }

      await docRef.update({'medicaments': mergeMap.values.toList()});

      return {'added': added, 'updated': updated, 'total': mergeMap.length};
    } catch (e) {
      debugPrint('Erreur importMedications: $e');
      rethrow;
    }
  }

  // ── Supprimer un médicament par index ──
  Future<void> deleteMedication(String pharmacyId, int index) async {
    try {
      final docRef = _db.collection('pharmacies').doc(pharmacyId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() ?? <String, dynamic>{};
      final List<dynamic> meds = List.from(data['medicaments'] ?? []);

      if (index < 0 || index >= meds.length) return;
      meds.removeAt(index);

      await docRef.update({'medicaments': meds});
    } catch (e) {
      debugPrint('Erreur deleteMedication: $e');
      rethrow;
    }
  }

  // ── Mettre à jour un médicament par index ──
  Future<void> updateMedication(
    String pharmacyId,
    int index,
    Map<String, dynamic> updatedMed,
  ) async {
    try {
      final docRef = _db.collection('pharmacies').doc(pharmacyId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data() ?? <String, dynamic>{};
      final List<dynamic> meds = List.from(data['medicaments'] ?? []);

      if (index < 0 || index >= meds.length) return;
      meds[index] = {
        ...updatedMed,
        'last_update': DateTime.now().toIso8601String(),
      };

      await docRef.update({'medicaments': meds});
    } catch (e) {
      debugPrint('Erreur updateMedication: $e');
      rethrow;
    }
  }

  // ── Récupérer toutes les pharmacies ──
  Stream<List<Pharmacy>> getPharmacies() {
    return _db.collection('pharmacies').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final localisation = data['localisation'] as Map<String, dynamic>?;
        return Pharmacy(
          id: doc.id,
          name: data['nom'] ?? '',
          address: data['adresse'] ?? '',
          latitude: (localisation?['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (localisation?['longitude'] as num?)?.toDouble() ?? 0.0,
          telephone: data['telephone'] ?? '',
          whatsapp: data['whatsapp'] ?? '',
          isActive: data['is_active'] ?? true,
        );
      }).toList();
    });
  }

  // ── Supprimer une pharmacie ──
  Future<void> deletePharmacy(String id) async {
    try {
      await _db.collection('pharmacies').doc(id).delete();
    } catch (e) {
      debugPrint('Erreur deletePharmacy: $e');
      rethrow;
    }
  }

  // ── Clé unique médicament (nom + dosage normalisé) ──
  String _medKey(Map<String, dynamic> med) {
    final nom = (med['nom'] ?? '').toString().toLowerCase().trim();
    final dosage = (med['dosage'] ?? '').toString().toLowerCase().trim();
    return '$nom|$dosage';
  }
}
