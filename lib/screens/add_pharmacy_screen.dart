// add_pharmacy_screen.dart — Avec import CSV/XLSX et affichage des médicaments

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import '../theme.dart';
import '../models/pharmacy.dart';
import '../services/firestore_service.dart';

class AddPharmacyScreen extends StatefulWidget {
  @override
  _AddPharmacyScreenState createState() => _AddPharmacyScreenState();
}

class _AddPharmacyScreenState extends State<AddPharmacyScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(3.848, 11.502);
  bool _loading = true;
  bool _isSaving = false;

  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // ── Fichier médicaments ──
  String? _selectedFileName;
  PlatformFile? _pickedFile;
  List<Map<String, dynamic>> _parsedMedications = [];
  bool _showMedPreview = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _loading = false);
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _loading = false);
        return;
      }
    }
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _loading = false;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
  }

  // ── Sélection et parsing du fichier CSV/XLSX ──
  Future<void> _pickMedicineFile(StateSetter setModalState) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );

      if (result == null) return;

      PlatformFile file = result.files.first;
      String extension = file.extension?.toLowerCase() ?? '';

      if (extension != 'csv' && extension != 'xlsx') {
        _showError('Format invalide ! Choisissez un fichier .csv ou .xlsx');
        return;
      }

      List<Map<String, dynamic>> parsed = [];

      if (extension == 'csv') {
        parsed = _parseCsv(file);
      } else {
        _showError(
          'Fichier XLSX détecté. Veuillez convertir en CSV pour ce moment.',
        );
        return;
      }

      if (parsed.isEmpty) {
        _showError('Aucun médicament trouvé dans le fichier.');
        return;
      }

      setModalState(() {
        _pickedFile = file;
        _selectedFileName = file.name;
        _parsedMedications = parsed;
        _showMedPreview = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${parsed.length} médicaments importés !'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Erreur lors de la sélection : $e');
    }
  }

  // ── Parsing CSV ──
  List<Map<String, dynamic>> _parseCsv(PlatformFile file) {
    final List<Map<String, dynamic>> result = [];
    try {
      final bytes = file.bytes;
      if (bytes == null) return result;

      String content = utf8.decode(bytes, allowMalformed: true);
      content = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
      if (content.isEmpty) return result;

      final delimiter = content.contains(';') && !content.contains(',')
          ? ';'
          : ',';
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(content, fieldDelimiter: delimiter, eol: '\n');

      if (rows.isEmpty) return result;

      final headers = (rows.first as List<dynamic>)
          .map((h) => h.toString().trim().toLowerCase().replaceAll('"', ''))
          .toList();

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i] as List<dynamic>;
        if (row.every((value) => value.toString().trim().isEmpty)) continue;

        final Map<String, dynamic> rowMap = {};
        for (int j = 0; j < headers.length && j < row.length; j++) {
          rowMap[headers[j]] = row[j].toString().trim();
        }

        final med = _normalizeMedication(rowMap);
        if (med != null) result.add(med);
      }
    } catch (e) {
      debugPrint('Erreur parsing CSV: $e');
    }
    return result;
  }

  // ── Normalisation des colonnes du CSV ──
  Map<String, dynamic>? _normalizeMedication(Map<String, dynamic> row) {
    // Cherche le nom dans plusieurs colonnes possibles
    final nom = (row['nom_medicament'] ?? row['nom'] ?? row['name'] ?? '')
        .toString()
        .trim();
    if (nom.isEmpty) return null;

    final prix =
        double.tryParse(
          (row['prix_fcfa'] ?? row['prix'] ?? row['price'] ?? '0').toString(),
        ) ??
        0;

    return {
      'id': row['id']?.toString() ?? '',
      'nom': nom,
      'dosage': (row['dosage'] ?? '').toString(),
      'forme': (row['forme'] ?? '').toString(),
      'categorie': (row['categorie'] ?? '').toString(),
      'fabricant': (row['fabricant'] ?? '').toString(),
      'prix': prix,
      'quantite':
          int.tryParse((row['quantite'] ?? row['stock'] ?? '0').toString()) ??
          0,
      'statut': _parseStatut(row['stock'] ?? row['statut'] ?? ''),
      'ordonnance': (row['ordonnance'] ?? '').toString().toLowerCase() == 'oui',
      'last_update': DateTime.now().toIso8601String(),
    };
  }

  String _parseStatut(dynamic stockVal) {
    final str = stockVal.toString().toLowerCase();
    if (str == 'oui' || str == 'en_stock' || str == 'disponible') {
      return 'en_stock';
    }
    return 'a_confirmer';
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Sauvegarde dans Firebase ──
  Future<void> _confirmRegistration() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      _showError('Veuillez remplir les champs obligatoires !');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pharmacy = Pharmacy(
        id: '',
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        telephone: _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        isActive: true,
      );

      // Sauvegarde la pharmacie avec les médicaments directement
      await _firestoreService.savePharmacy(
        pharmacy,
        medicaments: _parsedMedications.isNotEmpty ? _parsedMedications : null,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF10B981),
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                'Pharmacie enregistrée !',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_parsedMedications.isNotEmpty)
                Text(
                  '${_parsedMedications.length} médicaments importés avec succès.',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Erreur lors de l\'enregistrement : $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _loading || _isSaving
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showRegistrationSheet(context),
              backgroundColor: PharmaTheme.emeraldGreen,
              icon: const Icon(
                Icons.add_location_alt_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'ENREGISTRER ICI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Stack(
        children: [
          _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: PharmaTheme.emeraldGreen,
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 16,
                  ),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  padding: const EdgeInsets.only(top: 90),
                  onCameraMove: (p) => _currentPosition = p.target,
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected_pharma'),
                      position: _currentPosition,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                    ),
                  },
                ),
          Positioned(top: 0, left: 0, right: 0, child: _buildHeader()),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  color: PharmaTheme.emeraldGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showRegistrationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_pharmacy,
                            color: PharmaTheme.emeraldGreen,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Nouvelle Pharmacie',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildField(
                      _nameController,
                      "Nom de l'officine",
                      Icons.local_pharmacy_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      _addressController,
                      'Adresse physique',
                      Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      _phoneController,
                      'Numéro de téléphone',
                      Icons.phone_outlined,
                      type: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      _whatsappController,
                      'WhatsApp (ex: 2376XXXXXXXX)',
                      Icons.chat_bubble_outline_rounded,
                      type: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),

                    // ── Sélecteur de fichier ──
                    _buildFilePickerTile(setModalState),

                    // ── Aperçu des médicaments importés ──
                    if (_showMedPreview && _parsedMedications.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMedPreview(),
                    ],

                    const SizedBox(height: 24),
                    _buildConfirmButton(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Aperçu des médicaments importés ──
  Widget _buildMedPreview() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_parsedMedications.length} médicaments prêts à importer',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFBBF7D0)),
          // Affiche les 5 premiers
          ...(_parsedMedications
              .take(5)
              .map(
                (med) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.medication_rounded,
                        size: 14,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${med['nom']} ${med['dosage']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF065F46),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${med['prix']} FCFA',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          if (_parsedMedications.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                '... et ${_parsedMedications.length - 5} autres médicaments',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilePickerTile(StateSetter setModalState) {
    return InkWell(
      onTap: () => _pickMedicineFile(setModalState),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedFileName != null
                ? const Color(0xFF10B981)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.attach_file_rounded,
                color: PharmaTheme.emeraldGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Importer les médicaments',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedFileName ??
                        'Sélectionner un fichier .csv ou .xlsx',
                    style: TextStyle(
                      color: _selectedFileName != null
                          ? const Color(0xFF059669)
                          : Colors.grey[500],
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_selectedFileName != null)
              GestureDetector(
                onTap: () => setModalState(() {
                  _selectedFileName = null;
                  _pickedFile = null;
                  _parsedMedications = [];
                  _showMedPreview = false;
                }),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Color(0xFF263238),
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Text(
                'Enregistrer ma Pharmacie',
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    return GestureDetector(
      onTap: _confirmRegistration,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_rounded, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'CONFIRMER ET ENREGISTRER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
    );
  }
}
