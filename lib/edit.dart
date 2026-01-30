import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pharma/pageconnection/login_screen.dart'; 
import 'package:image_picker/image_picker.dart';
// Importez votre fichier de design system ici
 import 'package:pharma/theme/app_theme.dart'; 

class EditProfileScreen extends StatefulWidget {
  final String currentName;

  const EditProfileScreen({super.key, required this.currentName});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  File? _imageFile; 
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
      );

      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_profile_pic', pickedFile.path);

        setState(() {
          _imageFile = File(pickedFile.path);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Photo de profil mise à jour !")),
        );
      }
    } catch (e) {
      debugPrint("Erreur sélection image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String name = _nameController.text.trim();
    String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Modifier le Profil"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxl),
            
            // --- SECTION AVATAR ---
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: AppShadows.medium,
                      image: _imageFile != null 
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                    ),
                    child: _imageFile == null 
                      ? Center(
                          child: Text(
                            initial,
                            style: AppTypography.displayMedium.copyWith(color: AppColors.primary),
                          ),
                        )
                      : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: AppShadows.soft,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.huge),

            // --- CHAMP NOM D'UTILISATEUR ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Nom d'utilisateur",
                style: AppTypography.labelMedium.copyWith(color: AppColors.slate500),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            
            // Utilisation du style d'input du design system
            TextField(
              controller: _nameController,
              onChanged: (value) => setState(() {}),
              style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: "Votre nom",
                prefixIcon: const Icon(Icons.person_outline_rounded),
              ),
            ),

            const SizedBox(height: AppSpacing.massive),

            // --- BOUTON ENREGISTRER (Utilisant GradientButton du Design System) ---
            GradientButton(
              text: "Enregistrer les modifications",
              onPressed: () {
                if (_nameController.text.trim().isNotEmpty) {
                  Navigator.pop(context, _nameController.text.trim());
                } else {
                  _showErrorSnackBar(context);
                }
              },
            ),

            const SizedBox(height: AppSpacing.xl),
            
            // Bouton secondaire pour la déconnexion
            TextButton(
              onPressed: () => _showLogoutDialog(context),
              child: Text(
                "Déconnexion",
                style: AppTypography.buttonMedium.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Le nom ne peut pas être vide"),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Annuler")
          ),
          TextButton(
            onPressed: _handleLogout,
            child: const Text("Déconnexion", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); 
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, 
      );
    } catch (e) {
      debugPrint("Erreur déconnexion: $e");
    }
  }
}