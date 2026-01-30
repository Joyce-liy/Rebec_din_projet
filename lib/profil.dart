import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Ajouté
import 'package:firebase_auth/firebase_auth.dart'; // Ajouté
import 'package:google_sign_in/google_sign_in.dart'; // Ajouté
import 'package:pharma/edit.dart';
import 'package:pharma/pageconnection/login_screen.dart';
import 'package:pharma/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;

  const SettingsScreen({super.key, this.userName = "Joyce"});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late String localUserName;
  String? selectedQuartier;
  bool isFrench = true;
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;
  List<String> quartiers = [];
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    localUserName = widget.userName;
    loadQuartiers();
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> loadQuartiers() async {
    try {
      final String response =
          await rootBundle.loadString('assets/quartiers.json');
      final data = await json.decode(response);
      setState(() {
        quartiers = List<String>.from(data['yaounde']);
        if (quartiers.isNotEmpty) selectedQuartier = quartiers[0];
      });
    } catch (e) {
      debugPrint("Erreur chargement quartiers: $e");
    }
  }

  Future<void> _navigateToEdit() async {
    final String? newName = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EditProfileScreen(currentName: localUserName),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() => localUserName = newName);
    }
  }

  // --- LOGIQUE DE DÉCONNEXION MODIFIÉE ---
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Se déconnecter ?",
              style: AppTypography.headingMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "Vous devrez vous reconnecter pour accéder à votre compte.",
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: const BorderSide(color: AppColors.slate300),
                    ),
                    child: Text(
                      "Annuler",
                      style: AppTypography.buttonMedium.copyWith(
                        color: AppColors.slate600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.error, Color(0xFFFF6B6B)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          // 1. Fermer le dialogue
                          Navigator.pop(context);
                          
                          try {
                            // 2. Déconnexion Firebase
                            await FirebaseAuth.instance.signOut();
                            
                            // 3. Déconnexion Google
                            final GoogleSignIn googleSignIn = GoogleSignIn();
                            await googleSignIn.signOut();
                            
                            // 4. Nettoyage Local (SharedPreferences)
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();

                            // 5. Redirection vers Login
                            if (context.mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            debugPrint("Erreur lors de la déconnexion: $e");
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              "Déconnexion",
                              style: AppTypography.buttonMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String initial =
        localUserName.isNotEmpty ? localUserName[0].toUpperCase() : "J";

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildProfileCard(initial)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    _buildSectionLabel("PRÉFÉRENCES"),
                    const SizedBox(height: 12),
                    _buildSettingsCard([
                      _buildLocationRow(),
                      _buildDivider(),
                      _buildSwitchRow(
                        icon: Icons.language_rounded,
                        title: "Langue française",
                        subtitle: "Interface en français",
                        value: isFrench,
                        iconColor: AppColors.info,
                        onChanged: (val) => setState(() => isFrench = val),
                      ),
                      _buildDivider(),
                      _buildSwitchRow(
                        icon: Icons.notifications_rounded,
                        title: "Notifications",
                        subtitle: "Alertes de disponibilité",
                        value: notificationsEnabled,
                        iconColor: AppColors.warning,
                        onChanged: (val) =>
                            setState(() => notificationsEnabled = val),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    _buildSectionLabel("ASSISTANCE"),
                    const SizedBox(height: 12),
                    _buildSettingsCard([
                      _buildNavigationRow(
                        icon: Icons.emergency_rounded,
                        title: "Numéros d'urgence",
                        subtitle: "SAMU, Pompiers, Police",
                        iconColor: AppColors.error,
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildNavigationRow(
                        icon: Icons.help_outline_rounded,
                        title: "Centre d'aide",
                        subtitle: "FAQ et support",
                        iconColor: AppColors.secondary,
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildNavigationRow(
                        icon: Icons.info_outline_rounded,
                        title: "À propos",
                        subtitle: "Version 1.0.0",
                        iconColor: AppColors.primary,
                        onTap: () {},
                      ),
                    ]),
                    const SizedBox(height: 32),
                    _buildLogoutButton(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE CONSTRUCTION ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm, AppSpacing.md, AppSpacing.xl, 0,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.slate600,
              ),
            ),
          ),
          const Spacer(),
          Text(
            "Paramètres",
            style: AppTypography.headingSmall,
          ),
          const Spacer(),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String initial) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 0,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: AppTypography.displaySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localUserName,
                    style: AppTypography.headingMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Membre PharmConnect",
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _navigateToEdit,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: AppTypography.overline.copyWith(
          color: AppColors.slate400,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        color: AppColors.slate100,
      ),
    );
  }

  Widget _buildLocationRow() {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(
          "Mon quartier",
          style: AppTypography.labelLarge,
        ),
        subtitle: Text(
          "Zone de recherche préférée",
          style: AppTypography.caption.copyWith(
            color: AppColors.slate400,
          ),
        ),
        trailing: quartiers.isEmpty
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedQuartier,
                    isDense: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.slate600,
                      size: 20,
                    ),
                    items: quartiers.map((q) {
                      return DropdownMenuItem(
                        value: q,
                        child: Text(
                          q,
                          style: AppTypography.labelMedium,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => selectedQuartier = val),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color iconColor,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: AppTypography.labelLarge),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            color: AppColors.slate400,
          ),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildNavigationRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            title: Text(title, style: AppTypography.labelLarge),
            subtitle: Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.slate400,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.slate400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _showLogoutDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              "Se déconnecter",
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}