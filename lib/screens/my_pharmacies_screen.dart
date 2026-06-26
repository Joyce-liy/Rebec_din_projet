import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pharmacy.dart';
import '../theme.dart';

class MyPharmaciesScreen extends StatelessWidget {
  const MyPharmaciesScreen({Key? key}) : super(key: key);

  // ── Suppression avec confirmation ──
  Future<void> _confirmDelete(BuildContext context, Pharmacy pharmacy) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Supprimer la pharmacie ?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Voulez-vous vraiment supprimer\n"${pharmacy.name}" ?\n\nCette action est irréversible.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Annuler
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Annuler',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Supprimer
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFEF4444),
                              Color(0xFFDC2626),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Supprimer',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('pharmacies')
          .doc(pharmacy.id)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('"${pharmacy.name}" supprimée avec succès'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression : $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF0F172A)),
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
                            color:
                                PharmaTheme.emeraldGreen.withOpacity(0.3)),
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
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13),
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
                    latitude: (localisation?['latitude'] as num?)
                            ?.toDouble() ??
                        0.0,
                    longitude: (localisation?['longitude'] as num?)
                            ?.toDouble() ??
                        0.0,
                    telephone: data['telephone'] ?? '',
                    whatsapp: data['whatsapp'] ?? '',
                    isActive: data['is_active'] ?? true,
                  );
                }).toList();

                return Column(
                  children: [
                    // Compteur
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${pharmacies.length} pharmacie${pharmacies.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                         
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: pharmacies.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final p = pharmacies[i];
                          return _PharmacyCard(
                            pharmacy: p,
                            onTap: () => Navigator.pop(context, p),
                            onLongPress: () =>
                                _confirmDelete(context, p),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  final Pharmacy pharmacy;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PharmacyCard({
    required this.pharmacy,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
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
                  Row(
                    children: [
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
                      const SizedBox(width: 6),
                      // Hint suppression
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app_rounded,
                                size: 9, color: Color(0xFFEF4444)),
                            SizedBox(width: 3),
                            Text(
                              'Appui long',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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