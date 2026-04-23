import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pharmacy.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Ajouter ou mettre à jour une pharmacie
  Future<void> savePharmacy(Pharmacy pharmacy) async {
    try {
      await _db.collection('pharmacies').doc(pharmacy.id.isEmpty ? null : pharmacy.id).set(
        pharmacy.toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Erreur lors de l\'enregistrement de la pharmacie: $e');
      rethrow;
    }
  }

  // Récupérer toutes les pharmacies
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

  // Supprimer une pharmacie
  Future<void> deletePharmacy(String id) async {
    try {
      await _db.collection('pharmacies').doc(id).delete();
    } catch (e) {
      print('Erreur lors de la suppression: $e');
      rethrow;
    }
  }
}
