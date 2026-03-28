import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme.dart';

class AddPharmacyScreen extends StatefulWidget {
  @override
  _AddPharmacyScreenState createState() => _AddPharmacyScreenState();
}

class _AddPharmacyScreenState extends State<AddPharmacyScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = LatLng(3.848, 11.502); // Position par défaut (Yaoundé)
  bool _loading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();

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

    // Centrer la caméra sur la position trouvée
    _mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. UTILISATION DU BOUTON FLOTTANT
      floatingActionButton: _loading
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
          // FOND : GOOGLE MAPS
          _loading
              ? Center(child: CircularProgressIndicator(color: PharmaTheme.emeraldGreen))
              : GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 16),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            padding: EdgeInsets.only(top: 140),
            markers: {
              Marker(
                markerId: MarkerId("selected_pharma"),
                position: _currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            },
          ),

          // HEADER PREMIUM
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildHeader(),
          ),
        ],
      ),
    );
  }

  /// Affiche le formulaire dans un volet coulissant (Bottom Sheet)
  void _showRegistrationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important pour que le clavier ne cache pas tout
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Ajuste selon le clavier
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(25, 12, 25, 25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
          ),
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
                  Text("Informations",
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
                controller: _whatsappController,
                hint: "Contact WhatsApp Business",
                icon: Icons.chat_bubble_outline_rounded,
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 25),
              _buildConfirmButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PharmaTheme.emeraldGreen, Color(0xFF004D40)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Enregistrer ma Pharmacie",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Ma position est détectée par GPS",
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
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
          child: Text("CONFIRMER L'EMPLACEMENT",
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

  void _confirmRegistration() {
    if (_nameController.text.isEmpty || _whatsappController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Champs vides !"), backgroundColor: Colors.redAccent)
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Icon(Icons.verified, color: Colors.green, size: 50),
        content: Text("Enregistrement envoyé avec succès !", textAlign: TextAlign.center),
      ),
    );
  }
}