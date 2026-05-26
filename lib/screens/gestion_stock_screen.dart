//gestion des médicaments

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme.dart';

class GestionStockScreen extends StatefulWidget {
  final String pharmacyId;
  const GestionStockScreen({Key? key, required this.pharmacyId}) : super(key: key);

  @override
  _GestionStockScreenState createState() => _GestionStockScreenState();
}

class _GestionStockScreenState extends State<GestionStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  int _extractStock(Map<String, dynamic> med) {
    return int.tryParse((med['stock'] ?? med['quantite'] ?? med['qte'] ?? '0').toString()) ?? 0;
  }

  Future<void> _updateFirestoreList(List<dynamic> newList) async {
    await FirebaseFirestore.instance.collection('pharmacies').doc(widget.pharmacyId.trim()).update({'medicaments': newList});
  }

  void _showMedDialog(BuildContext context, List<dynamic> currentList, {Map<String, dynamic>? medToEdit, int? index}) {
    final bool isEditing = medToEdit != null;
    final TextEditingController nomCtrl = TextEditingController(text: isEditing ? medToEdit['nom'] : '');
    final TextEditingController stockCtrl = TextEditingController(text: isEditing ? _extractStock(medToEdit).toString() : '');
    final TextEditingController prixCtrl = TextEditingController(text: isEditing ? (medToEdit['prix'] ?? 0).toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEditing ? "Modifier" : "Ajouter", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomCtrl, decoration: const InputDecoration(labelText: "Nom")),
            TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock")),
            TextField(controller: prixCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Prix (FCFA)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PharmaTheme.emeraldGreen),
            onPressed: () async {
              List<dynamic> newList = List.from(currentList);
              final newMed = {'nom': nomCtrl.text, 'stock': int.tryParse(stockCtrl.text) ?? 0, 'prix': int.tryParse(prixCtrl.text) ?? 0};
              isEditing ? newList[index!] = newMed : newList.add(newMed);
              await _updateFirestoreList(newList);
              Navigator.pop(context);
            },
            child: Text(isEditing ? "Enregistrer" : "Ajouter", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text("Gestion du Stock", style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2C3E50)), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('pharmacies').doc(widget.pharmacyId.trim()).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final List<dynamic> medicaments = data != null && data.containsKey('medicaments') ? List.from(data['medicaments']) : [];
          final filtered = medicaments.where((m) => (m['nom'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(hintText: "Rechercher...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final med = filtered[index] as Map<String, dynamic>;
                    final originalIndex = medicaments.indexOf(med);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.medication, color: PharmaTheme.emeraldGreen)),
                        title: Text(med['nom'] ?? 'Sans nom', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Stock: ${_extractStock(med)} | ${med['prix'] ?? 0} FCFA"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), onPressed: () => _showMedDialog(context, medicaments, medToEdit: med, index: originalIndex)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () async {
                              List<dynamic> newList = List.from(medicaments);
                              newList.removeAt(originalIndex);
                              await _updateFirestoreList(newList);
                            }),
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
        stream: FirebaseFirestore.instance.collection('pharmacies').doc(widget.pharmacyId.trim()).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final List<dynamic> currentList = data != null ? List.from(data['medicaments'] ?? []) : [];
          return FloatingActionButton(backgroundColor: PharmaTheme.emeraldGreen, onPressed: () => _showMedDialog(context, currentList), child: const Icon(Icons.add));
        },
      ),
    );
  }
}