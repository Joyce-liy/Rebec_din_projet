import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/pharmacy.dart';
import '../theme.dart';
import 'add_pharmacy_screen.dart';
import 'subscription_screen.dart';
import 'create_ad_screen.dart';
import 'settings_screen.dart';
import 'statistique_screen.dart';
import 'gestion_stock_screen.dart';
import 'welcome_screen.dart';

class PharmacistHubScreen extends StatefulWidget {
  const PharmacistHubScreen({super.key});

  @override
  _PharmacistHubScreenState createState() => _PharmacistHubScreenState();
}

class _PharmacistHubScreenState extends State<PharmacistHubScreen> {
  User? _currentUser;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  Pharmacy? _selectedPharmacy; // pharmacie active choisie depuis StatistiqueScreen

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => WelcomeScreen()),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Se déconnecter'),
          content: Text('Voulez-vous vraiment vous déconnecter ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Non'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: PharmaTheme.emeraldGreen,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Oui'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFD),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 15),

                    _buildManagementBanner(context),

                    const SizedBox(height: 30),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.95,
                      children: [
                        _buildActionCard(
                          context,
                          "Ma Pharmacie",
                          "Localisation GPS",
                          Icons.location_on_rounded,
                          PharmaTheme.emeraldGreen,
                          AddPharmacyScreen(), //connexion à la page de création des pharmacies
                        ),
                        _buildActionCard(
                          context,
                          "Abonnement",
                          "Gérer mon offre",
                          Icons.auto_awesome_rounded,
                          Colors.orangeAccent,
                          SubscriptionScreen(), // connexion à la page d'abonnement
                        ),
                        _buildActionCard(
                          context,
                          "Publicité",
                          "Booster les vues",
                          Icons.rocket_launch_rounded,
                          Colors.blueAccent,
                          CreateAdScreen(), //pour souscrire à une publicité
                        ),
                        _buildActionCard(
                          context,
                          "Gestion",
                          _selectedPharmacy != null
                              ? _selectedPharmacy!.name
                              : "Vues et clics",
                          Icons.bar_chart_rounded,
                          Colors.purpleAccent,
                          StatistiqueScreen(pharmacy: _selectedPharmacy),
                        ),
                      ],
                    ),

                    const SizedBox(height: 35),
                    const Text(
                      "Assistance & Réglages",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // --- PAS DE 'const' ICI CAR onTap EST DYNAMIQUE ---
                    _buildOptionTile(
                      Icons.help_center_rounded,
                      "Centre d'aide",
                      "Besoin d'aide ?",
                      onTap: () {
                        // Action Aide
                      },
                    ),
                    _buildOptionTile(
                      Icons.settings_rounded,
                      "Paramètres",
                      "Configuration",
                      onTap: () {
                        // NAVIGATION VERS SETTINGS
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [PharmaTheme.emeraldGreen, const Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: PharmaTheme.emeraldGreen.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Gestion de l'officine",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddPharmacyScreen(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Créer une pharmacie",
                      style: TextStyle(
                        color: PharmaTheme.emeraldGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.add_business_rounded, color: Colors.white, size: 45),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String userName = _currentUser?.displayName ?? "Utilisateur";
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: PharmaTheme.emeraldGreen.withOpacity(0.1),
            child: Icon(Icons.person_rounded, color: PharmaTheme.emeraldGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              userName,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2D3436),
              ),
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  size: 26,
                  color: Color(0xFF2D3436),
                ),
                onPressed: () {
                  // Action pour les notifications
                },
              ),
              IconButton(
                icon: Icon(Icons.logout, size: 26, color: Color(0xFF2D3436)),
                onPressed: _confirmLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget? target,
  ) {
    return GestureDetector(
      onTap: () async {
        if (target != null) {
          final result = await Navigator.push<Pharmacy>(
            context,
            MaterialPageRoute(builder: (context) => target),
          );
          // Si StatistiqueScreen retourne une pharmacie sélectionnée, on met à jour le hub
          if (result != null && mounted) {
            setState(() => _selectedPharmacy = result);
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.blueGrey, size: 22),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      ),
    );
  }
}