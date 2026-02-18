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
  LatLng _currentPosition = LatLng(3.848, 11.502); // Position par défaut (Cameroun)
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. FOND : GOOGLE MAPS PLEIN ÉCRAN
          _loading
              ? Center(child: CircularProgressIndicator(color: PharmaTheme.emeraldGreen))
              : GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 16),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            padding: EdgeInsets.only(top: 140, bottom: 300), // Évite de cacher les logos Google
            markers: {
              Marker(
                markerId: MarkerId("selected_pharma"),
                position: _currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
            },
          ),

          // 2. HEADER PREMIUM (Dégradé Émeraude & Design)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PharmaTheme.emeraldGreen,
                    Color(0xFF004D40), // Vert Nuit profond
                  ],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  )
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      // Bouton retour stylisé
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                      SizedBox(width: 15),
                      // Titre et Sous-titre
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Enregistrer ma Pharmacie",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Position GPS détectée automatiquement",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Icon(Icons.location_on, color: Colors.white38, size: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. CARTE FLOTTANTE DE SAISIE (Bas de l'écran)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: EdgeInsets.all(15),
              padding: EdgeInsets.fromLTRB(25, 12, 25, 25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Poignée de décoration (Handle)
                  Container(
                    width: 45,
                    height: 5,
                    margin: EdgeInsets.only(bottom: 25),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Titre de la section
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: PharmaTheme.emeraldGreen, size: 28),
                      SizedBox(width: 10),
                      Text(
                        "Informations",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF263238),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Champ Nom de la Pharmacie
                  _buildModernField(
                    controller: _nameController,
                    hint: "Nom de l'officine",
                    icon: Icons.local_pharmacy_outlined,
                  ),
                  SizedBox(height: 15),

                  // Champ WhatsApp
                  _buildModernField(
                    controller: _whatsappController,
                    hint: "Contact WhatsApp Business",
                    icon: Icons.chat_bubble_outline_rounded,
                    keyboardType: TextInputType.phone,
                  ),

                  SizedBox(height: 25),

                  // Bouton d'action avec dégradé
                  GestureDetector(
                    onTap: () => _confirmRegistration(),
                    child: Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [PharmaTheme.emeraldGreen, Color(0xFF00695C)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: PharmaTheme.emeraldGreen.withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "CONFIRMER L'EMPLACEMENT",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
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

  /// Design des champs de texte
  Widget _buildModernField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen.withOpacity(0.7), size: 22),
        filled: true,
        fillColor: Color(0xFFF8F9FA), // Gris très clair pour le contraste sur fond blanc
        contentPadding: EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[100]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: PharmaTheme.emeraldGreen.withOpacity(0.5), width: 1.5),
        ),
      ),
    );
  }

  void _confirmRegistration() {
    if (_nameController.text.isEmpty || _whatsappController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Veuillez remplir tous les champs"), backgroundColor: Colors.redAccent)
      );
      return;
    }

    // Simulation d'enregistrement
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Icon(Icons.verified_user, color: PharmaTheme.emeraldGreen, size: 50),
        content: Text("Demande d'enregistrement envoyée à l'administrateur.", textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Fermer"))
        ],
      ),
    );
  }
}