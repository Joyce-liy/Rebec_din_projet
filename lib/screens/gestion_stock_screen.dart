// gestion_stock_screen.dart — Suppression Firebase corrigée

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class GestionStockScreen extends StatefulWidget {
  final String pharmacyId;
  const GestionStockScreen({Key? key, required this.pharmacyId})
    : super(key: key);

  @override
  _GestionStockScreenState createState() => _GestionStockScreenState();
}

class _GestionStockScreenState extends State<GestionStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Référence Firestore ──
  DocumentReference get _pharmacyRef => FirebaseFirestore.instance
      .collection('pharmacies')
      .doc(widget.pharmacyId.trim());

  int _extractStock(Map<String, dynamic> med) {
    return int.tryParse(
          (med['stock'] ?? med['quantite'] ?? med['qte'] ?? '0').toString(),
        ) ??
        0;
  }

  // ── Mise à jour de la liste dans Firestore ──
  Future<void> _updateFirestoreList(List<dynamic> newList) async {
    await _pharmacyRef.update({'medicaments': newList});
  }

  // ── Suppression d'un médicament par son index ──
  Future<void> _deleteMedication(List<dynamic> currentList, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Supprimer ?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous supprimer "${currentList[index]['nom']}" du stock ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final List<dynamic> newList = List.from(currentList);
      newList.removeAt(index);
      await _updateFirestoreList(newList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Médicament supprimé avec succès'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

  // ── Dialog ajout / modification ──
  void _showMedDialog(
    BuildContext context,
    List<dynamic> currentList, {
    Map<String, dynamic>? medToEdit,
    int? index,
  }) {
    final bool isEditing = medToEdit != null;
    final nomCtrl = TextEditingController(
      text: isEditing ? medToEdit['nom'] : '',
    );
    final dosageCtrl = TextEditingController(
      text: isEditing ? (medToEdit['dosage'] ?? '') : '',
    );
    final stockCtrl = TextEditingController(
      text: isEditing ? _extractStock(medToEdit).toString() : '',
    );
    final prixCtrl = TextEditingController(
      text: isEditing ? (medToEdit['prix'] ?? 0).toString() : '',
    );

    String statut = isEditing
        ? (medToEdit['statut'] ?? medToEdit['status'] ?? 'en_stock')
        : 'en_stock';

    final List<Map<String, String>> statuts = [
      {'value': 'en_stock', 'label': 'En stock'},
      {'value': 'stock_limite', 'label': 'Stock limité'},
      {'value': 'rupture', 'label': 'Rupture'},
      {'value': 'a_confirmer', 'label': 'À confirmer'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isEditing ? 'Modifier le médicament' : 'Ajouter un médicament',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                  nomCtrl,
                  'Nom du médicament',
                  Icons.medication_outlined,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  dosageCtrl,
                  'Dosage (ex: 500mg)',
                  Icons.science_outlined,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  stockCtrl,
                  'Quantité en stock',
                  Icons.inventory_2_outlined,
                  inputType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _dialogField(
                  prixCtrl,
                  'Prix (FCFA)',
                  Icons.attach_money_rounded,
                  inputType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                // Statut
                DropdownButtonFormField<String>(
                  value: statut,
                  decoration: InputDecoration(
                    labelText: 'Statut du stock',
                    prefixIcon: const Icon(
                      Icons.toggle_on_outlined,
                      color: PharmaTheme.emeraldGreen,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: statuts
                      .map(
                        (s) => DropdownMenuItem(
                          value: s['value'],
                          child: Text(s['label']!),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => statut = val ?? 'en_stock'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: PharmaTheme.emeraldGreen,
              ),
              onPressed: () async {
                if (nomCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Le nom est obligatoire')),
                  );
                  return;
                }
                List<dynamic> newList = List.from(currentList);
                final newMed = {
                  'nom': nomCtrl.text.trim(),
                  'dosage': dosageCtrl.text.trim(),
                  'quantite': int.tryParse(stockCtrl.text.trim()) ?? 0,
                  'stock': int.tryParse(stockCtrl.text.trim()) ?? 0,
                  'prix': double.tryParse(prixCtrl.text.trim()) ?? 0,
                  'statut': statut,
                  'last_update': DateTime.now().toIso8601String(),
                };
                isEditing ? newList[index!] = newMed : newList.add(newMed);
                await _updateFirestoreList(newList);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                isEditing ? 'Enregistrer' : 'Ajouter',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
    );
  }

  Color _statutColor(String? statut) {
    switch (statut) {
      case 'en_stock':
        return const Color(0xFF10B981);
      case 'stock_limite':
        return const Color(0xFFF59E0B);
      case 'rupture':
        return const Color(0xFFEF4444);
      case 'a_confirmer':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _statutLabel(String? statut) {
    switch (statut) {
      case 'en_stock':
        return 'En stock';
      case 'stock_limite':
        return 'Stock limité';
      case 'rupture':
        return 'Rupture';
      case 'a_confirmer':
        return 'À confirmer';
      default:
        return 'Inconnu';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF0F172A),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gestion du Stock',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _pharmacyRef.snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final count = (data?['medicaments'] as List?)?.length ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count médicaments',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _pharmacyRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: PharmaTheme.emeraldGreen),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final List<dynamic> medicaments =
              data != null && data.containsKey('medicaments')
              ? List.from(data['medicaments'])
              : [];

          final filtered = medicaments
              .where(
                (m) => (m['nom'] ?? '').toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

          return Column(
            children: [
              // Barre de recherche
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un médicament...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: Colors.grey[400]),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),

              // Statistiques rapides
              if (medicaments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      _StatBadge(
                        label: 'En stock',
                        count: medicaments
                            .where(
                              (m) =>
                                  m['statut'] == 'en_stock' ||
                                  m['status'] == 'en_stock',
                            )
                            .length,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      _StatBadge(
                        label: 'Limité',
                        count: medicaments
                            .where(
                              (m) =>
                                  m['statut'] == 'stock_limite' ||
                                  m['status'] == 'stock_limite',
                            )
                            .length,
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      _StatBadge(
                        label: 'Rupture',
                        count: medicaments
                            .where(
                              (m) =>
                                  m['statut'] == 'rupture' ||
                                  m['status'] == 'rupture',
                            )
                            .length,
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ),

              // Liste
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 60,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Aucun médicament dans le stock'
                                  : 'Aucun résultat pour "$_searchQuery"',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final med = filtered[index] as Map<String, dynamic>;
                          final originalIndex = medicaments.indexOf(med);
                          final statut =
                              med['statut'] ?? med['status'] ?? 'a_confirmer';
                          final statusColor = _statutColor(statut);
                          final stock = _extractStock(med);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  // Icône statut
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.medication_rounded,
                                      color: statusColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          med['nom'] ?? 'Sans nom',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        if (med['dosage'] != null &&
                                            med['dosage'].toString().isNotEmpty)
                                          Text(
                                            med['dosage'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            // Badge statut
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                _statutLabel(statut),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Qté: $stock',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${med['prix'] ?? 0} FCFA',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF059669),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Actions
                                  Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          color: Color(0xFF3B82F6),
                                          size: 20,
                                        ),
                                        onPressed: () => _showMedDialog(
                                          context,
                                          medicaments,
                                          medToEdit: med,
                                          index: originalIndex,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(height: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 20,
                                        ),
                                        onPressed: () => _deleteMedication(
                                          medicaments,
                                          originalIndex,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
        stream: _pharmacyRef.snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final List<dynamic> currentList = data != null
              ? List.from(data['medicaments'] ?? [])
              : [];
          return FloatingActionButton.extended(
            backgroundColor: PharmaTheme.emeraldGreen,
            onPressed: () => _showMedDialog(context, currentList),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Ajouter',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Badge statistique ──
class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
