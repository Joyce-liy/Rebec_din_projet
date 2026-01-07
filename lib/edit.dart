import 'package:flutter/material.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;

  // Le constructeur demande le nom actuel pour l'afficher dans le champ
  const EditProfileScreen({super.key, required this.currentName});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // Initialise le champ de texte avec le nom actuel
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    // Toujours libérer le contrôleur pour éviter les fuites de mémoire
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Modifier le profil"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nom d'utilisateur",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: "Entrez votre nouveau nom",
                prefixIcon: const Icon(Icons.person_outline, color: Colors.green),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                String newName = _nameController.text.trim();
                
                if (newName.isNotEmpty) {
                  // Renvoie le nouveau nom à la page précédente (SettingsScreen)
                  Navigator.pop(context, newName);
                } else {
                  // Affiche une erreur si le champ est vide
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Le nom ne peut pas être vide")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "ENREGISTRER",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}