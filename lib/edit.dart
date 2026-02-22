import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pharma/pageconnection/login_screen.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:pharma/user_data_service.dart';
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
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _loadProfileImage();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Charger l'image de profil de l'utilisateur connecté
  Future<void> _loadProfileImage() async {
    setState(() => _isLoadingImage = true);
    
    try {
      final imagePath = await UserDataService.instance.getProfilePicture();
      
      print('Chargement de l\'image: $imagePath');
      
      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          // Force le rafraîchissement en créant une nouvelle instance de File
          setState(() {
            _imageFile = File(imagePath);
          });
          print('Image chargée: $imagePath');
        } else {
          print(' Fichier image introuvable: $imagePath');
          setState(() => _imageFile = null);
        }
      } else {
        print('Aucune image de profil');
        setState(() => _imageFile = null);
      }
    } catch (e) {
      print('Erreur lors du chargement de l\'image: $e');
      setState(() => _imageFile = null);
    } finally {
      setState(() => _isLoadingImage = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        print('Image sélectionnée: ${pickedFile.path}');
        
        // Sauvegarder pour l'utilisateur connecté (copie dans un emplacement permanent)
        await UserDataService.instance.saveProfilePicture(pickedFile.path);
        
        // Recharger l'image depuis l'emplacement permanent
        await _loadProfileImage();
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo de profil mise à jour !"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur sélection image: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection de l'image: $e"),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _removeImage() async {
    try {
      await UserDataService.instance.deleteProfilePicture();
      setState(() => _imageFile = null);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Photo de profil supprimée"),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("Erreur suppression image: $e");
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
        actions: [
          // Bouton pour afficher les infos de debug
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              await UserDataService.instance.debugPrintAllData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Données affichées dans la console")),
              );
            },
          ),
        ],
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
                  // Avatar principal
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: AppShadows.medium,
                      image: _imageFile != null 
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    ),
                    child: _isLoadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : _imageFile == null 
                        ? Center(
                            child: Text(
                              initial,
                              style: AppTypography.displayMedium.copyWith(color: AppColors.primary),
                            ),
                          )
                        : null,
                  ),
                  
                  // Bouton pour changer l'image
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
                  
                  // Bouton pour supprimer l'image (si elle existe)
                  if (_imageFile != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _removeImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: AppShadows.soft,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
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
              onPressed: () async {
                if (_nameController.text.trim().isNotEmpty) {
                  // Sauvegarder le nom pour l'utilisateur connecté
                  await UserDataService.instance.saveUserName(_nameController.text.trim());
                  
                  print(' Nom sauvegardé: ${_nameController.text.trim()}');
                  
                  if (!mounted) return;
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
      print(' Déconnexion en cours...');
      
      // Effacer uniquement les données de session (pas les données utilisateur)
      await UserDataService.instance.clearSessionData();
      
      // Déconnexion Firebase et Google
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      
      print(' Déconnexion réussie');
      
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, 
      );
    } catch (e) {
      debugPrint(" Erreur déconnexion: $e");
    }
  }
}