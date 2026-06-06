import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import 'claim_pharmacy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;
  String selectedLanguage = 'Français';

  User? get _user => FirebaseAuth.instance.currentUser;

  /// Retourne le nom d'affichage : priorité au displayName,
  /// sinon la partie avant le @ de l'email, sinon "Utilisateur"
  String get _displayName {
    final user = _user;
    if (user == null) return 'Utilisateur';
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    final email = user.email ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return 'Utilisateur';
  }

  String get _displayEmail => _user?.email ?? '';

  @override
  Widget build(BuildContext context) {
    // --- GESTION DYNAMIQUE DES COULEURS ---
    final Color backgroundColor = isDarkMode ? const Color(0xFF121212) : const Color(0xFFFBFDFD);
    final Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF2D3436);
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.grey;

    return Scaffold(
      backgroundColor: backgroundColor, // La couleur change ici
      appBar: AppBar(
        title: Text("Paramètres",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER VERT ÉMÉRAUDE ---
            _buildUserHeader(),

            const SizedBox(height: 35),
            Text("Préférences",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: subTextColor)
            ),
            const SizedBox(height: 15),

            // --- OPTION THÈME ---
            _buildSettingTile(
              backgroundColor: cardColor,
              textColor: textColor,
              icon: Icons.dark_mode_rounded,
              title: "Mode Sombre",
              subtitle: isDarkMode ? "Activé" : "Désactivé",
              trailing: Switch(
                value: isDarkMode,
                activeColor: PharmaTheme.emeraldGreen,
                onChanged: (value) {
                  setState(() {
                    isDarkMode = value;
                  });
                },
              ),
            ),

            // --- OPTION LANGUE ---
            _buildSettingTile(
              backgroundColor: cardColor,
              textColor: textColor,
              icon: Icons.language_rounded,
              title: "Langue",
              subtitle: selectedLanguage,
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subTextColor),
              onTap: () {
                _showLanguageDialog(cardColor, textColor);
              },
            ),

            const SizedBox(height: 25),
            Text("Compte",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: subTextColor)
            ),
            const SizedBox(height: 15),

            _buildSettingTile(
              backgroundColor: cardColor,
              textColor: textColor,
              icon: Icons.lock_outline_rounded,
              title: "Changer le mot de passe",
              subtitle: "Sécurité du compte",
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subTextColor),
            ),

            _buildSettingTile(
              backgroundColor: cardColor,
              textColor: textColor,
              icon: Icons.store_rounded,
              title: "Récupérer mes anciennes pharmacies",
              subtitle: "Migration vers le nouveau système",
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subTextColor),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClaimPharmacyScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER STYLE ÉMÉRAUDE & BLANC ---
  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PharmaTheme.emeraldGreen, // Fond vert
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: PharmaTheme.emeraldGreen.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8)
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2), // Rond blanc transparent
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 35),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Profil connecté",
                    style: TextStyle(color: Colors.white70, fontSize: 13)
                ),
                Text(
                  _displayName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_displayEmail.isNotEmpty)
                  Text(
                    _displayEmail,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required Color backgroundColor,
    required Color textColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: PharmaTheme.emeraldGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)
          ),
          child: Icon(icon, color: PharmaTheme.emeraldGreen),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6))),
        trailing: trailing,
      ),
    );
  }

  void _showLanguageDialog(Color bgColor, Color txtColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Choisir une langue",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: txtColor)
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text("Français", style: TextStyle(color: txtColor)),
                onTap: () { setState(() => selectedLanguage = "Français"); Navigator.pop(context); },
              ),
              ListTile(
                title: Text("English", style: TextStyle(color: txtColor)),
                onTap: () { setState(() => selectedLanguage = "English"); Navigator.pop(context); },
              ),
            ],
          ),
        );
      },
    );
  }
}