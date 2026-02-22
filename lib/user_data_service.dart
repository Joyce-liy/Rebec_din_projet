import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart'; // Nécessaire pour ValueNotifier

/// Service pour gérer les données utilisateur de manière isolée par compte
class UserDataService {
  static final UserDataService instance = UserDataService._();
  UserDataService._();

  // Ajout d'un notifier pour que l'interface sache quand la photo change
  final ValueNotifier<String?> profilePicNotifier = ValueNotifier<String?>(null);

  /// Obtenir l'ID unique de l'utilisateur connecté
  String? _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  /// Générer une clé préfixée avec l'ID utilisateur
  String _getUserKey(String key) {
    final userId = _getCurrentUserId();
    if (userId == null) throw Exception("Aucun utilisateur connecté");
    return "user_${userId}_$key";
  }

  Future<Directory> _getProfilePicturesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final profilePicsDir = Directory('${appDir.path}/profile_pictures');
    if (!await profilePicsDir.exists()) {
      await profilePicsDir.create(recursive: true);
    }
    return profilePicsDir;
  }

  Future<String> _getUserProfilePicturePath() async {
    final userId = _getCurrentUserId();
    if (userId == null) throw Exception("Aucun utilisateur connecté");
    final dir = await _getProfilePicturesDirectory();
    return '${dir.path}/profile_$userId.jpg';
  }

  // ============================================
  // MÉTHODES DE SAUVEGARDE
  // ============================================

  Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getUserKey('name'), name);
  }

  /// Sauvegarder l'image de profil (copie le fichier et notifie l'app)
  Future<void> saveProfilePicture(String sourcePath) async {
    try {
      final destinationPath = await _getUserProfilePicturePath();
      final sourceFile = File(sourcePath);
      
      final destFile = File(destinationPath);
      if (await destFile.exists()) {
        await destFile.delete();
      }
      
      await sourceFile.copy(destinationPath);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getUserKey('profile_pic'), destinationPath);
      
      // CRUCIAL: On prévient les widgets que l'image a changé
      profilePicNotifier.value = destinationPath;
      
      print('✅ Image sauvegardée et notifiée: $destinationPath');
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde de l\'image: $e');
      rethrow;
    }
  }

  Future<void> deleteProfilePicture() async {
    try {
      final picturePath = await getProfilePicture();
      if (picturePath != null) {
        final file = File(picturePath);
        if (await file.exists()) await file.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getUserKey('profile_pic'));
      
      profilePicNotifier.value = null; // Notifier la suppression
    } catch (e) {
      print('Erreur lors de la suppression de l\'image: $e');
    }
  }

  Future<void> saveHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_getUserKey('history'), jsonEncode(history));
  }

  Future<void> addToHistory(String item) async {
    final history = await getHistory();
    history.insert(0, item);
    if (history.length > 50) history.removeRange(50, history.length);
    await saveHistory(history);
  }

  Future<void> clearHistory() async {
    await saveHistory([]);
  }

  // ============================================
  // MÉTHODES DE RÉCUPÉRATION
  // ============================================

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_getUserKey('name'));
  }

  Future<String?> getProfilePicture() async {
    final prefs = await SharedPreferences.getInstance();
    final picPath = prefs.getString(_getUserKey('profile_pic'));
    
    if (picPath != null) {
      final file = File(picPath);
      if (await file.exists()) {
        // Mettre à jour le notifier au cas où il est null au démarrage
        profilePicNotifier.value = picPath;
        return picPath;
      } else {
        await prefs.remove(_getUserKey('profile_pic'));
        profilePicNotifier.value = null;
      }
    }
    return null;
  }

  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_getUserKey('history'));
    if (historyJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================
  // MÉTHODES DE GESTION DE COMPTE
  // ============================================

  Future<void> clearSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    // On ne touche PAS aux clés "user_ID_..."
    await prefs.remove('session_token');
    await prefs.remove('is_logged_in');
  }

  Future<void> initializeNewUser(String defaultName) async {
    final existingName = await getUserName();
    if (existingName == null) {
      await saveUserName(defaultName);
      await saveHistory([]);
    }
    // Charger la photo au démarrage
    await getProfilePicture();
  }

  Future<bool> isFirstLogin() async {
    final userName = await getUserName();
    return userName == null;
  }

  Future<void> debugPrintAllData() async {}
}