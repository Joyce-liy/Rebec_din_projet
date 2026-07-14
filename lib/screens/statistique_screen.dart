// statistique_screen.dart — Avec upload CSV lors de la modification

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pharm_admin/l10n/app_localizations.dart';
import '../models/pharmacy.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import 'gestion_stock_screen.dart';
import 'my_pharmacies_screen.dart';

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

  // ── CSV Upload ──
  String? _selectedFileName;
  PlatformFile? _pickedFile;
  List<Map<String, dynamic>> _parsedMedications = [];
  bool _isImporting = false;

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

  Future<void> _loadMedicamentCount() async {
    if (_currentPharmacy == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('pharmacies')
          .doc(_currentPharmacy!.id)
          .get();
      final data = doc.data();
      final meds = data?['medicaments'] as List?;
      setState(() => _medicamentCount = meds?.length ?? 0);
    } catch (e) {
      debugPrint('Erreur comptage médicaments: $e');
    }
  }

  Future<void> _loadPharmacyFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('pharmacies')
          .get();
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
      }
    } catch (e) {
      debugPrint('Erreur chargement pharmacie: $e');
    } finally {
      setState(() => _isLoading = false);
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

  // ────────────────────────────────────────────
  // Parsing CSV
  // ────────────────────────────────────────────
  List<Map<String, dynamic>> _parseCsv(PlatformFile file) {
    final List<Map<String, dynamic>> result = [];
    try {
      final bytes = file.bytes;
      if (bytes == null) return result;
      final content = utf8.decode(bytes);
      final lines = content.split('\n');
      if (lines.isEmpty) return result;

      final headers = lines[0]
          .split(',')
          .map((h) => h.trim().toLowerCase().replaceAll('"', ''))
          .toList();

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final values = line
            .split(',')
            .map((v) => v.trim().replaceAll('"', ''))
            .toList();
        if (values.length < 2) continue;

        final Map<String, dynamic> row = {};
        for (int j = 0; j < headers.length && j < values.length; j++) {
          row[headers[j]] = values[j];
        }
        final med = _normalizeMed(row);
        if (med != null) result.add(med);
      }
    } catch (e) {
      debugPrint('Erreur parsing CSV: $e');
    }
    return result;
  }

  Map<String, dynamic>? _normalizeMed(Map<String, dynamic> row) {
    final nom = (row['nom_medicament'] ?? row['nom'] ?? row['name'] ?? '')
        .toString()
        .trim();
    if (nom.isEmpty) return null;
    return {
      'id': row['id']?.toString() ?? '',
      'nom': nom,
      'dosage': (row['dosage'] ?? '').toString(),
      'forme': (row['forme'] ?? '').toString(),
      'categorie': (row['categorie'] ?? '').toString(),
      'fabricant': (row['fabricant'] ?? '').toString(),
      'prix':
          double.tryParse(
            (row['prix_fcfa'] ?? row['prix'] ?? '0').toString(),
          ) ??
          0,
      'quantite':
          int.tryParse((row['quantite'] ?? row['stock'] ?? '0').toString()) ??
          0,
      'statut': _parseStatut(row['stock'] ?? row['statut'] ?? ''),
      'ordonnance': (row['ordonnance'] ?? '').toString().toLowerCase() == 'oui',
      'last_update': DateTime.now().toIso8601String(),
    };
  }

  String _parseStatut(dynamic val) {
    final s = val.toString().toLowerCase();
    if (s == 'oui' || s == 'en_stock' || s == 'disponible') return 'en_stock';
    return 'a_confirmer';
  }

  // ────────────────────────────────────────────
  // Sélection du fichier CSV
  // ────────────────────────────────────────────
  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null) return;

      final file = result.files.first;
      final ext = file.extension?.toLowerCase() ?? '';
      if (ext != 'csv') {
        _showSnackBar('Format invalide ! Choisissez un .csv', Colors.redAccent);
        return;
      }

      final parsed = _parseCsv(file);
      if (parsed.isEmpty) {
        _showSnackBar(
          'Aucun médicament trouvé dans le fichier.',
          Colors.orange,
        );
        return;
      }

      setState(() {
        _pickedFile = file;
        _selectedFileName = file.name;
        _parsedMedications = parsed;
      });

      _showSnackBar(
        '${parsed.length} médicaments chargés. Appuyez sur "Importer" pour confirmer.',
        const Color(0xFF3B82F6),
      );
    } catch (e) {
      _showSnackBar('Erreur : $e', Colors.redAccent);
    }
  }

  // ────────────────────────────────────────────
  // Import avec fusion — évite les doublons
  // ────────────────────────────────────────────
  Future<void> _importMedications() async {
    if (_currentPharmacy == null || _parsedMedications.isEmpty) return;

    setState(() => _isImporting = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('pharmacies')
          .doc(_currentPharmacy!.id);

      // Récupère les médicaments existants
      final doc = await docRef.get();
      final data = doc.data();
      final List<dynamic> existing = List.from(data?['medicaments'] ?? []);

      // Fusion : écrase si le même nom+dosage existe, sinon ajoute
      final Map<String, Map<String, dynamic>> mergeMap = {};

      // Charger les existants dans la map (clé = nom+dosage normalisé)
      for (final med in existing) {
        final m = med as Map<String, dynamic>;
        final key = _medKey(m);
        mergeMap[key] = m;
      }

      int updated = 0;
      int added = 0;

      for (final newMed in _parsedMedications) {
        final key = _medKey(newMed);
        if (mergeMap.containsKey(key)) {
          // Écrase l'ancien — garde l'id existant
          mergeMap[key] = {
            ...mergeMap[key]!,
            ...newMed,
            'last_update': DateTime.now().toIso8601String(),
          };
          updated++;
        } else {
          mergeMap[key] = newMed;
          added++;
        }
      }

      final mergedList = mergeMap.values.toList();

      await docRef.update({'medicaments': mergedList});

      setState(() {
        _medicamentCount = mergedList.length;
        _selectedFileName = null;
        _pickedFile = null;
        _parsedMedications = [];
      });

      _showSnackBar(
        '$added ajouté(s) • $updated mis à jour • Total: ${mergedList.length}',
        const Color(0xFF10B981),
      );
    } catch (e) {
      _showSnackBar('Erreur lors de l\'import : $e', Colors.redAccent);
    } finally {
      setState(() => _isImporting = false);
    }
  }

  // Clé unique pour identifier un médicament (nom + dosage)
  String _medKey(Map<String, dynamic> med) {
    final nom = (med['nom'] ?? '').toString().toLowerCase().trim();
    final dosage = (med['dosage'] ?? '').toString().toLowerCase().trim();
    return '$nom|$dosage';
  }

  // ────────────────────────────────────────────
  // Mise à jour infos pharmacie
  // ────────────────────────────────────────────
  Future<void> _updatePharmacyDetails() async {
    if (_currentPharmacy == null) return;
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      _showSnackBar(
        context.t('le_nom_et_telephone_obligatoires'),
        Colors.redAccent,
      );
      return;
    }
    setState(() => _isUpdating = true);
    try {
      final updated = Pharmacy(
        id: _currentPharmacy!.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _currentPharmacy!.latitude,
        longitude: _currentPharmacy!.longitude,
        telephone: _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        isActive: _isActive,
      );
      await _firestoreService.savePharmacy(updated);
      _showSnackBar(
        context.t('informations_enregistrees'),
        PharmaTheme.emeraldGreen,
      );
      setState(() => _isReadOnly = true);
    } catch (e) {
      _showSnackBar('Erreur : $e', Colors.redAccent);
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: PharmaTheme.emeraldGreen),
        ),
      );
    }
    if (_currentPharmacy == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.t('dashboard'))),
        body: Center(child: Text(context.t('no_pharmacy_found'))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(
          context.t('my_officine'), // ← C’est ça le changement principal

          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF2C3E50),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isReadOnly)
            TextButton.icon(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.redAccent,
                size: 18,
              ),
              label: Text(
                context.t('cancel'),
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => setState(() {
                _isReadOnly = true;
                _initFields();
                _selectedFileName = null;
                _parsedMedications = [];
              }),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Bannière pharmacie ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_pharmacy,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentPharmacy!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentPharmacy!.address.isEmpty
                                  ? context.t('adresse_non_renseignee')
                                  : _currentPharmacy!.address,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Stats ──
                Row(
                  children: [
                    Expanded(
                      child: _buildMicroStatCard(
                        context.t('medicaments'),
                        '$_medicamentCount',
                        Icons.medication_rounded,
                        const Color(0xFF10B981),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GestionStockScreen(
                              pharmacyId: _currentPharmacy!.id,
                            ),
                          ),
                        ).then((_) => _loadMedicamentCount()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMicroStatCard(
                        context.t('mes_pharmacies'),
                        context.t('changer'),
                        Icons.store_rounded,
                        const Color(0xFF6366F1),
                        onTap: () async {
                          final selected = await Navigator.push<Pharmacy>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyPharmaciesScreen(),
                            ),
                          );
                          if (selected != null && mounted) {
                            setState(() {
                              _currentPharmacy = selected;
                              _isActive = selected.isActive;
                              _initFields();
                            });
                            _loadMedicamentCount();
                            // Retourner aussi la pharmacie au hub
                            Navigator.pop(context, selected);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Formulaire infos ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildResponsiveField(
                        controller: _nameController,
                        label: context.t('nom_etablissement'),
                        icon: Icons.store_rounded,
                      ),
                      _buildDivider(),
                      _buildResponsiveField(
                        controller: _addressController,
                        label: context.t('adresse_geographique'),
                        icon: Icons.map_rounded,
                      ),
                      _buildDivider(),
                      _buildResponsiveField(
                        controller: _phoneController,
                        label: context.t('numero_telephone'),
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildDivider(),
                      _buildResponsiveField(
                        controller: _whatsappController,
                        label: context.t('whatsapp_pro'),
                        icon: Icons.chat_bubble_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Switch visibilité ──
                if (!_isReadOnly)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        context.t('visible_on_map'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      subtitle: Text(
                        context.t('clients_can_find_your_pharmacy'),
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _isActive,
                      activeColor: PharmaTheme.emeraldGreen,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ),

                // ── Section Import CSV (visible en mode édition) ──
                if (!_isReadOnly) ...[
                  const SizedBox(height: 16),
                  _buildCsvImportSection(),
                ],

                const SizedBox(height: 24),

                // ── Bouton principal ──
                GestureDetector(
                  onTap: _isUpdating
                      ? null
                      : () {
                          if (_isReadOnly) {
                            setState(() => _isReadOnly = false);
                          } else {
                            _updatePharmacyDetails();
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isReadOnly
                            ? [const Color(0xFF2C3E50), const Color(0xFF1A252F)]
                            : [
                                PharmaTheme.emeraldGreen,
                                const Color(0xFF059669),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (_isReadOnly
                                      ? const Color(0xFF2C3E50)
                                      : PharmaTheme.emeraldGreen)
                                  .withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isReadOnly
                                ? Icons.edit_note_rounded
                                : Icons.save_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isUpdating
                                ? context.t('enregistrement')
                                : (_isReadOnly
                                      ? context.t('modifier_les_informations')
                                      : context.t('enregistrer_la_fiche')),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isUpdating || _isImporting)
            Container(
              color: Colors.black26,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _isImporting
                          ? context.t('import_en_cours')
                          : context.t('enregistrement'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // Widget section import CSV
  // ────────────────────────────────────────────
  Widget _buildCsvImportSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _selectedFileName != null
              ? const Color(0xFF10B981)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: PharmaTheme.emeraldGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.t('upload_csv_medications'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.t('doublons_ecrases'),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 14),

          // Bouton sélection fichier
          GestureDetector(
            onTap: _pickCsvFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file_rounded,
                    color: PharmaTheme.emeraldGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedFileName ??
                          context.t('selectionner_fichier_csv'),
                      style: TextStyle(
                        fontSize: 13,
                        color: _selectedFileName != null
                            ? const Color(0xFF059669)
                            : Colors.grey[500],
                        fontWeight: _selectedFileName != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedFileName != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedFileName = null;
                        _pickedFile = null;
                        _parsedMedications = [];
                      }),
                      child: const Icon(
                        Icons.cancel_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Aperçu médicaments parsés
          if (_parsedMedications.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_parsedMedications.length} ${context.t('medicaments_prets')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Aperçu 3 premiers
                  ..._parsedMedications
                      .take(3)
                      .map(
                        (med) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.fiber_manual_record,
                                size: 6,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${med['nom']} • ${med['dosage']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF065F46),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${med['prix']} F',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (_parsedMedications.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '... ${context.t('autres')} ${_parsedMedications.length - 3}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Bouton importer
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isImporting ? null : _importMedications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: _isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                label: Text(
                  _isImporting
                      ? context.t('import_en_cours')
                      : context.t('importer_dans_firebase'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // Widgets UI communs
  // ────────────────────────────────────────────
  Widget _buildMicroStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
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
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: onTap != null
                          ? PharmaTheme.emeraldGreen
                          : const Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    if (_isReadOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF7F8C8D), size: 20),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.text.isEmpty ? 'Non renseigné' : controller.text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF2C3E50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: PharmaTheme.emeraldGreen,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: PharmaTheme.emeraldGreen,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return _isReadOnly
        ? Divider(color: Colors.grey[100], height: 1, thickness: 1, indent: 35)
        : const SizedBox(height: 4);
  }
}
