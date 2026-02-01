import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pharma/user_data_service.dart';

class GlobalUserAvatar extends StatelessWidget {
  final double radius;
  final String userName;

  const GlobalUserAvatar({
    super.key, 
    required this.radius, 
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    // Le ValueListenableBuilder écoute le "notifier" dans votre service.
    // Dès que saveProfilePicture est appelé, ce builder se reconstruit partout.
    return ValueListenableBuilder<String?>(
      valueListenable: UserDataService.instance.profilePicNotifier,
      builder: (context, imagePath, child) {
        
        // Vérification si le chemin existe et si le fichier est physiquement présent
        bool hasImage = imagePath != null && 
                         imagePath.isNotEmpty && 
                         File(imagePath).existsSync();

        if (hasImage) {
          return CircleAvatar(
            radius: radius,
            key: ValueKey(imagePath), // Force le rafraîchissement visuel
            backgroundImage: FileImage(File(imagePath!)),
            backgroundColor: Colors.grey.shade200,
          );
        } else {
          // Affichage par défaut avec l'initiale
          String initial = userName.isNotEmpty ? userName[0].toUpperCase() : "U";
          
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.green.shade600,
            child: Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
      },
    );
  }
}