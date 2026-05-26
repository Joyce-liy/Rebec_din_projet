// affichages des informations d'une pharmacies

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pharmacy.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import 'gestion_stock_screen.dart';

class StatistiqueScreen extends StatefulWidget {
  final Pharmacy? pharmacy;

  const StatistiqueScreen({Key? key, this.pharmacy}) : super(key: key);

  @override
  _StatistiqueScreenState createState() => _StatistiqueScreenState();
}

class _StatistiqueScreenState extends State<StatistiqueScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isUpdating = false;
  bool _isLoading = true;
  bool _isReadOnly = true;
  Pharmacy? _currentPharmacy;
  int _medicamentCount = 0;

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _whatsappController = TextEditingController();

    if (widget.pharmacy != null) {
      _currentPharmacy = widget.pharmacy;
      _initFields();
      _loadMedicamentCount();
      _isLoading = false;
    } else {
      _loadPharmacyFromFirestore();
    }
  }

  void _initFields() {
    if (_currentPharmacy == null) return;
    _nameController.text = _currentPharmacy!.name;
    _addressController.text = _currentPharmacy!.address;
    _phoneController.text = _currentPharmacy!.telephone;
    _whatsappController.text = _currentPharmacy!.whatsapp;
    _isActive = _currentPharmacy!.isActive;
  }

  /// AJOUT : Compte le nombre de médicaments de manière optimisée
  Future<void> _loadMedicamentCount() async {
    if (_currentPharmacy == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pharmacies')
          .doc(_currentPharmacy!.id)
          .collection('medicaments')
          .count()
          .get();

      setState(() {
        _medicamentCount = snapshot.count ?? 0;
      });
    } catch (e) {
      print("Erreur lors du comptage des médicaments : $e");
    }
  }

  Future<void> _loadPharmacyFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('pharmacies').get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final localisation = data['localisation'] as Map<String, dynamic>?;

        setState(() {
          _currentPharmacy = Pharmacy(
            id: doc.id,
            name: data['nom'] ?? '',
            address: data['adresse'] ?? '',
            latitude: (localisation?['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (localisation?['longitude'] as num?)?.toDouble() ?? 0.0,
            telephone: data['telephone'] ?? '',
            whatsapp: data['whatsapp'] ?? '',
            isActive: data['is_active'] ?? true,
          );
          _initFields();
        });

        await _loadMedicamentCount();
        setState(() { _isLoading = false; });
      } else {
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      print("Erreur lors du chargement de la pharmacie: $e");
      setState(() { _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _updatePharmacyDetails() async {
    if (_currentPharmacy == null) return;
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      _showSnackBar("Le nom et le téléphone sont obligatoires", Colors.redAccent);
      return;
    }

    setState(() { _isUpdating = true; });

    try {
      final updatedPharmacy = Pharmacy(
        id: _currentPharmacy!.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _currentPharmacy!.latitude,
        longitude: _currentPharmacy!.longitude,
        telephone: _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        isActive: _isActive,
      );

      await _firestoreService.savePharmacy(updatedPharmacy);

      _showSnackBar("Informations enregistrées avec succès !", PharmaTheme.emeraldGreen);
      setState(() { _isReadOnly = true; });
    } catch (e) {
      _showSnackBar("Erreur lors de la mise à jour : $e", Colors.redAccent);
    } finally {
      setState(() { _isUpdating = false; });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: PharmaTheme.emeraldGreen)),
      );
    }

    if (_currentPharmacy == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Tableau de bord")),
        body: const Center(child: Text("Aucune pharmacie trouvée.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: const Text("Mon Officine", style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.w900, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2C3E50), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isReadOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 18),
                label: const Text("Annuler", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() {
                    _isReadOnly = true;
                    _initFields();
                  });
                },
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. BANNIÈRE HÉRO PREMIUM ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [PharmaTheme.emeraldGreen, const Color(0xFF004D40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: PharmaTheme.emeraldGreen.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.local_pharmacy_rounded, color: Colors.white70, size: 32),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isActive ? const Color(0xE3E8F5E9) : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isActive ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isActive ? "OUVERT" : "FERMÉ",
                                  style: TextStyle(
                                    color: _isActive ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _nameController.text.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white60, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _addressController.text.isEmpty ? "Adresse non spécifiée" : _addressController.text,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w400),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),

                // --- 2. SECTION STATS EN MICRO-CARTES (MODIFIÉ ICI) ---
                Row(
                  children: [
                    Expanded(
                      child: _buildMicroStatCard(
                        "État Médicaments",
                        _medicamentCount > 0 ? "$_medicamentCount réf." : "Ouvrir",
                        Icons.medication_rounded,
                        PharmaTheme.emeraldGreen,
                        onTap: () async {
                          // Redirection vers l'écran de gestion du stock
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GestionStockScreen(pharmacyId: _currentPharmacy!.id),
                            ),
                          );
                          // Rechargement du compteur au retour de la page
                          _loadMedicamentCount();
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildMicroStatCard(
                        "Justificatif",
                        _currentPharmacy!.id.isNotEmpty ? "Vérifié" : "Manquant",
                        Icons.verified_user_rounded,
                        Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Titre de section élégant
                Row(
                  children: [
                    Container(width: 4, height: 18, decoration: BoxDecoration(color: PharmaTheme.emeraldGreen, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 8),
                    Text(
                      _isReadOnly ? "Fiche d'identité" : "Modification des données",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // --- 3. FORMULAIRE CARD UNIQUE ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildResponsiveField(controller: _nameController, label: "Nom de l'établissement", icon: Icons.store_rounded),
                      _buildDivider(),
                      _buildResponsiveField(controller: _addressController, label: "Adresse Géographique", icon: Icons.map_rounded),
                      _buildDivider(),
                      _buildResponsiveField(controller: _phoneController, label: "Numéro de Ligne", icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone),
                      _buildDivider(),
                      _buildResponsiveField(controller: _whatsappController, label: "Lien WhatsApp Pro", icon: Icons.chat_bubble_rounded, keyboardType: TextInputType.phone),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Carte du Switch visibilité
                if (!_isReadOnly)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SwitchListTile(
                      title: const Text("Rendre visible sur la carte", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                      subtitle: const Text("Permet aux clients de Yaoundé de trouver votre officine", style: TextStyle(fontSize: 12)),
                      value: _isActive,
                      activeColor: PharmaTheme.emeraldGreen,
                      onChanged: (value) => setState(() { _isActive = value; }),
                    ),
                  ),
                const SizedBox(height: 35),


                GestureDetector(
                  onTap: _isUpdating
                      ? null
                      : () {
                    if (_isReadOnly) {
                      setState(() { _isReadOnly = false; });
                    } else {
                      _updatePharmacyDetails();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: _isReadOnly
                              ? [const Color(0xFF2C3E50), const Color(0xFF1A252F)]
                              : [PharmaTheme.emeraldGreen, const Color(0xFF00695C)]
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (_isReadOnly ? const Color(0xFF2C3E50) : PharmaTheme.emeraldGreen).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isReadOnly ? Icons.edit_note_rounded : Icons.save_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _isUpdating
                                ? "MIGRATION EN COURS..."
                                : (_isReadOnly ? "MODIFIER LES INFORMATIONS" : "ENREGISTRER LA FICHE"),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isUpdating)
            Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }

  // MODIFICATION ICI
  Widget _buildMicroStatCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 18,
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: onTap != null ? PharmaTheme.emeraldGreen : const Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) // Petite flèche discrète si la carte possède une action de navigation
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboardType = TextInputType.text}) {
    if (_isReadOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF7F8C8D), size: 20),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  Text(
                      controller.text.isEmpty ? "Non renseigné" : controller.text,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50), fontWeight: FontWeight.w600)
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PharmaTheme.emeraldGreen)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15, color: Color(0xFF2C3E50), fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: PharmaTheme.emeraldGreen, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return _isReadOnly
        ? Divider(color: Colors.grey[100], height: 1, thickness: 1, indent: 35)
        : const SizedBox(height: 5);
  }
}