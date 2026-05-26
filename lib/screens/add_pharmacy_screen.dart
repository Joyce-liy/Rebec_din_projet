import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import '../theme.dart';
import '../models/pharmacy.dart';
import '../services/firestore_service.dart';

class AddPharmacyScreen extends StatefulWidget {
  @override
  _AddPharmacyScreenState createState() => _AddPharmacyScreenState();
}

class _AddPharmacyScreenState extends State<AddPharmacyScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = LatLng(3.848, 11.502); // Position par défaut (Yaoundé)
  bool _loading = true;
  bool _isSaving = false;

  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // <-- 2. VARIABLES POUR LE FICHIER DE MÉDICAMENTS
  String? _selectedFileName;
  PlatformFile? _pickedFile;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  /// Gestion de la localisation GPS
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _loading = false;
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
  }

  /// <-- 3. MÉTHODE DE SÉLECTION ET VALIDATION DU FICHIER
  Future<void> _pickMedicineFile(StateSetter setModalState) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'], // Restriction native au niveau de l'OS
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        String extension = file.extension?.toLowerCase() ?? '';

        // Double vérification stricte de l'extension
        if (extension == 'csv' || extension == 'xlsx') {
          setModalState(() {
            _pickedFile = file;
            _selectedFileName = file.name;
          });
        } else {
          _showErrorSnackBar("Format invalide ! Veuillez choisir un fichier .csv ou .xlsx");
        }
      }
    } catch (e) {
      _showErrorSnackBar("Erreur lors de la sélection du fichier : $e");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _loading || _isSaving
          ? null
          : FloatingActionButton.extended(
        onPressed: () => _showRegistrationSheet(context),
        backgroundColor: PharmaTheme.emeraldGreen,
        icon: Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: Text("ENREGISTRER ICI",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: Stack(
        children: [
          _loading
              ? Center(child: CircularProgressIndicator(color: PharmaTheme.emeraldGreen))
              : GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 16),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            padding: EdgeInsets.only(top: 90), // Réduit pour correspondre au nouveau header soft
            onCameraMove: (position) {
              _currentPosition = position.target;
            },
            markers: {
              Marker(
                markerId: MarkerId("selected_pharma"),
                position: _currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            },
          ),

          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildHeader(),
          ),
          if (_isSaving)
            Container(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator(color: PharmaTheme.emeraldGreen)),
            ),
        ],
      ),
    );
  }

  /// Affiche le formulaire dans un volet coulissant (Bottom Sheet)
  void _showRegistrationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder( // <-- 4. AJOUT DU STATEFULBUILDER POUR METTRE À JOUR LE MODAL IN REALTIME
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(25, 12, 25, 25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 45, height: 5,
                      margin: EdgeInsets.only(bottom: 25),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                    Row(
                      children: [
                        Icon(Icons.edit_note_rounded, color: PharmaTheme.emeraldGreen, size: 28),
                        SizedBox(width: 10),
                        Text("Informations de la Pharmacie",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238))
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    _buildModernField(
                      controller: _nameController,
                      hint: "Nom de l'officine",
                      icon: Icons.local_pharmacy_outlined,
                    ),
                    SizedBox(height: 15),
                    _buildModernField(
                      controller: _addressController,
                      hint: "Adresse physique",
                      icon: Icons.location_on_outlined,
                    ),
                    SizedBox(height: 15),
                    _buildModernField(
                      controller: _phoneController,
                      hint: "Numéro de téléphone",
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 15),
                    _buildModernField(
                      controller: _whatsappController,
                      hint: "Contact WhatsApp (ex: 2376XXXXXXXX)",
                      icon: Icons.chat_bubble_outline_rounded,
                      keyboardType: TextInputType.phone,
                    ),

                    // <-- 5. DESIGN DU BOUTON D'AJOUT DE MÉDICAMENT APRÈS WHATSAPP
                    SizedBox(height: 15),
                    _buildFilePickerTile(setModalState),

                    SizedBox(height: 25),
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

  /// <-- 6. COMPOSANT VISUEL POUR LE SÉLECTEUR DE FICHIER (CORRIGÉ !)
  Widget _buildFilePickerTile(StateSetter setModalState) {
    return InkWell(
      onTap: () => _pickMedicineFile(setModalState),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _selectedFileName != null ? PharmaTheme.emeraldGreen : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icône en forme d'épingle / trombone
            Icon(Icons.attach_file_rounded, color: PharmaTheme.emeraldGreen),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ajouts des médicaments",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF263238)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _selectedFileName ?? "Sélectionner un fichier (.csv, .xlsx)",
                    style: TextStyle(
                      color: _selectedFileName != null ? Colors.black54 : Colors.grey[500],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_selectedFileName != null)
              GestureDetector(
                onTap: () {
                  setModalState(() {
                    _selectedFileName = null;
                    _pickedFile = null;
                  });
                },
                child: Icon(Icons.cancel_rounded, color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }

  /// Nouveau Design du Header : Carte blanche flottante et minimaliste
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
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: Color(0xFF263238), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              SizedBox(width: 6),
              Text(
                "Enregistrer ma Pharmacie",
                style: TextStyle(
                  color: Color(0xFF263238),
                  fontSize: 16,
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
      onTap: () {
        Navigator.pop(context); // Ferme le formulaire avant de valider
        _confirmRegistration();
      },
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [PharmaTheme.emeraldGreen, Color(0xFF00695C)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text("CONFIRMER ET ENREGISTRER",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ),
      ),
    );
  }

  Widget _buildModernField({required TextEditingController controller, required String hint, required IconData icon, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen),
        filled: true,
        fillColor: Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _confirmRegistration() async {
    if (_nameController.text.isEmpty || _whatsappController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Veuillez remplir les champs obligatoires !"), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final pharmacy = Pharmacy(
        id: "",
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        telephone: _phoneController.text.trim(),
        whatsapp: _whatsappController.text.trim(),
        isActive: true,
      );

      await _firestoreService.savePharmacy(pharmacy);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Icon(Icons.verified, color: Colors.green, size: 50),
          content: Text("Pharmacie enregistrée avec succès dans la base de données !", textAlign: TextAlign.center),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'enregistrement : $e"), backgroundColor: Colors.redAccent)
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}