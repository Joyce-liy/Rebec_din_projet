
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/pharmacy.dart';
 
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
 
  // ── UID de l'utilisateur connecté ──
  String? get _currentUid => _auth.currentUser?.uid;
 
  // ── Sauvegarder / mettre à jour une pharmacie ──
  Future<String> savePharmacy(
    Pharmacy pharmacy, {
    List<Map<String, dynamic>>? medicaments,
  }) async {
    try {
      final uid = _currentUid;
      if (uid == null) throw Exception('Utilisateur non connecté');
 
      final docRef = pharmacy.id.isEmpty
          ? _db.collection('pharmacies').doc()
          : _db.collection('pharmacies').doc(pharmacy.id);
 
      final data = pharmacy.toFirestore();
 
      // Toujours associer l'owner_uid à la création
      // SetOptions(merge: true) ne l'écrasera pas si déjà présent
      if (pharmacy.id.isEmpty) {
        data['owner_uid'] = uid;
      }
 
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
 
  // ── Récupérer UNIQUEMENT les pharmacies de l'utilisateur connecté ──
  // Gère les deux cas :
  //   1. Nouvelles pharmacies → owner_uid == uid
  //   2. Anciennes pharmacies sans owner_uid → owner_uid == null ou champ absent
  //      → affichées SEULEMENT si claimées (voir claimLegacyPharmacies)
  Stream<List<Pharmacy>> getPharmacies() {
    final uid = _currentUid;
    if (uid == null) return Stream.value([]);
 
    return _db
        .collection('pharmacies')
        .where('owner_uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
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
 
  // ── Migration : récupérer les pharmacies "orphelines" (sans owner_uid) ──
  // À appeler depuis un écran de réclamation ou un script admin
  Future<List<Map<String, dynamic>>> getOrphanPharmacies() async {
    try {
      // Firestore ne supporte pas whereNull directement, on filtre côté client
      final snapshot = await _db.collection('pharmacies').get();
      return snapshot.docs
          .where((doc) => !doc.data().containsKey('owner_uid'))
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Erreur getOrphanPharmacies: $e');
      rethrow;
    }
  }
 
  // ── Migration : associer une pharmacie orpheline à l'utilisateur connecté ──
  // Le pharmacien reconnaît sa pharmacie dans la liste et la "réclame"
  Future<void> claimPharmacy(String pharmacyId) async {
    final uid = _currentUid;
    if (uid == null) throw Exception('Utilisateur non connecté');
 
    try {
      await _db.collection('pharmacies').doc(pharmacyId).update({
        'owner_uid': uid,
        'claimed_at': DateTime.now().toIso8601String(),
      });
      debugPrint('Pharmacie $pharmacyId associée à $uid');
    } catch (e) {
      debugPrint('Erreur claimPharmacy: $e');
      rethrow;
    }
  }
 
  // ── Import CSV avec fusion (sans doublons) ──
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
 
      final Map<String, Map<String, dynamic>> mergeMap = {};
      for (final med in existing) {
        final m = Map<String, dynamic>.from(med as Map);
        mergeMap[_medKey(m)] = m;
      }
 
      for (final newMed in newMeds) {
        final key = _medKey(newMed);
        if (mergeMap.containsKey(key)) {
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
 