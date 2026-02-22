import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Si tu utilises Google Maps
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class CreatePharmaScreen extends StatefulWidget {
  const CreatePharmaScreen({super.key});

  @override
  State<CreatePharmaScreen> createState() => _CreatePharmaScreenState();
}

class _CreatePharmaScreenState extends State<CreatePharmaScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs pour récupérer le texte
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  LatLng? _selectedLocation;
  bool _isLocating = false;

  // Fonction pour récupérer la position actuelle de la pharmacie
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    var status = await Permission.location.request();
    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Enregistrer ma Pharmacie"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Informations Générales", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 15),
              
              // Nom de la pharmacie
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Nom de l'officine",
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.isEmpty ? "Obligatoire" : null,
              ),
              const SizedBox(height: 15),

              // WhatsApp Business
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Numéro WhatsApp Business",
                  prefixIcon: const Icon(Icons.phone),
                  hintText: "Ex: 690000000",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.isEmpty ? "Obligatoire pour les commandes" : null,
              ),
              const SizedBox(height: 15),

              const Divider(),
              const Text("Localisation", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 10),
              
              // Bouton Localisation GPS
              ListTile(
                tileColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(Icons.location_on, color: _selectedLocation != null ? Colors.green : Colors.red),
                    title: Text(_selectedLocation == null 
                      ? "Position GPS non définie" 
                      : "Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)} | Long: ${_selectedLocation!.longitude.toStringAsFixed(4)}"),
                trailing: _isLocating 
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _getCurrentLocation,
                      child: const Text("Pointer"),
                    ),
              ),
              const SizedBox(height: 30),

              // Bouton de Validation Final
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate() && _selectedLocation != null) {
                      // Ici on enverra les données vers Firebase ou ton API
                      _savePharmacy();
                    } else if (_selectedLocation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Veuillez pointer la localisation GPS"))
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text("Créer l'officine", 
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _savePharmacy() {
    // Logique pour sauvegarder en base de données
    print("Nom: ${_nameController.text}");
    print("Position: ${_selectedLocation}");
    Navigator.pop(context); // Retour à l'accueil après succès
  }
}