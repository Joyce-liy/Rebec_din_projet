import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pharmacy.dart';
import '../theme.dart';

/// Page qui liste toutes les pharmacies appartenant à l'utilisateur connecté.
/// Quand il clique sur une pharmacie, on retourne l'objet [Pharmacy] au caller
/// via Navigator.pop() — le hub se met à jour en conséquence.
class MyPharmaciesScreen extends StatelessWidget {
  const MyPharmaciesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mes Pharmacies',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Non connecté'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pharmacies')
                  .where('owner_uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: PharmaTheme.emeraldGreen),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_pharmacy_outlined,
                            size: 72,
                            color: PharmaTheme.emeraldGreen.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune pharmacie trouvée',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Créez votre première pharmacie depuis le hub.',
                          style:
                              TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final pharmacies = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final localisation =
                      data['localisation'] as Map<String, dynamic>?;
                  return Pharmacy(
                    id: doc.id,
                    name: data['nom'] ?? '',
                    address: data['adresse'] ?? '',
                    latitude:
                        (localisation?['latitude'] as num?)?.toDouble() ?? 0.0,
                    longitude:
                        (localisation?['longitude'] as num?)?.toDouble() ?? 0.0,
                    telephone: data['telephone'] ?? '',
                    whatsapp: data['whatsapp'] ?? '',
                    isActive: data['is_active'] ?? true,
                  );
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: pharmacies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final p = pharmacies[i];
                    return _PharmacyCard(
                      pharmacy: p,
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  final Pharmacy pharmacy;
  final VoidCallback onTap;

  const _PharmacyCard({required this.pharmacy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_pharmacy_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pharmacy.name.isEmpty ? 'Sans nom' : pharmacy.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (pharmacy.address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      pharmacy.address,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Badge statut
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: pharmacy.isActive
                          ? const Color(0xFF10B981).withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pharmacy.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: pharmacy.isActive
                            ? const Color(0xFF10B981)
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Flèche
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}