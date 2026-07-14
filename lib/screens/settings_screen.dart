import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_language.dart';
import '../l10n/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
    selectedLanguage = AppLanguage.instance.value.languageCode == 'en'
        ? 'English'
        : 'Français';
  }

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
    final Color backgroundColor = isDarkMode
        ? const Color(0xFF121212)
        : const Color(0xFFFBFDFD);
    final Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF2D3436);
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.grey;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          context.t('settings'),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
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
            _buildUserHeader(),

            const SizedBox(height: 35),
            Text(
              context.t('preferences'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 15),

            _buildSettingTile(
              backgroundColor: cardColor,
              textColor: textColor,
              icon: Icons.dark_mode_rounded,
              title: context.t('theme_mode'),
              subtitle: isDarkMode
                  ? context.t('enabled')
                  : context.t('disabled'),
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

            _buildSettingTile(
              backgroundColor: cardColor,
              textColor: textColor,
              icon: Icons.language_rounded,
              title: context.t('language'),
              subtitle: selectedLanguage,
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: subTextColor,
              ),
              onTap: () {
                _showLanguageDialog(cardColor, textColor);
              },
            ),

            const SizedBox(height: 25),
            Text(
              context.t('account'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: subTextColor,
              ),
            ),
            const SizedBox(height: 15),

            _buildSettingTile(
              backgroundColor: cardColor,
              textColor: textColor,
              icon: Icons.lock_outline_rounded,
              title: context.t('change_password'),
              subtitle: context.t('configuration'),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: subTextColor,
              ),
              onTap: () =>
                  _showChangePasswordSheet(cardColor, textColor, isDarkMode),
            ),

            _buildSettingTile(
              backgroundColor: cardColor,
              textColor: textColor,
              icon: Icons.store_rounded,
              title: context.t('recover_pharmacies'),
              subtitle: context.t('migration_note'),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: subTextColor,
              ),
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

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PharmaTheme.emeraldGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: PharmaTheme.emeraldGreen.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 35,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('connected_profile'),
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
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
    VoidCallback? onTap,
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: PharmaTheme.emeraldGreen),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6)),
        ),
        trailing: trailing,
      ),
    );
  }

  void _showLanguageDialog(Color bgColor, Color txtColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t('choose_language'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: txtColor,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(
                  context.t('french'),
                  style: TextStyle(color: txtColor),
                ),
                onTap: () {
                  setState(() {
                    selectedLanguage = context.t('french');
                  });
                  AppLanguage.instance.updateLocale(const Locale('fr'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(
                  context.t('english'),
                  style: TextStyle(color: txtColor),
                ),
                onTap: () {
                  setState(() {
                    selectedLanguage = context.t('english');
                  });
                  AppLanguage.instance.updateLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- PANNEAU MODERNE DE CHANGEMENT DE MOT DE PASSE ---
  void _showChangePasswordSheet(Color cardColor, Color textColor, bool isDark) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;
    String? errorText;

    final Color sheetBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final Color fieldFill = isDark
        ? const Color(0xFF262626)
        : const Color(0xFFF5F8F7);
    final Color subTextColor = isDark ? Colors.white60 : Colors.grey.shade600;

    double strength(String password) {
      if (password.isEmpty) return 0;
      double score = 0;
      if (password.length >= 6) score++;
      if (password.length >= 10) score++;
      if (RegExp(r'[A-Z]').hasMatch(password) &&
          RegExp(r'[0-9]').hasMatch(password))
        score++;
      if (RegExp(r'[!@#\$&*~%_\-.]').hasMatch(password)) score++;
      return score.clamp(0, 4);
    }

    Color strengthColor(double s) {
      switch (s.toInt()) {
        case 1:
          return const Color(0xFFE74C3C);
        case 2:
          return const Color(0xFFF39C12);
        case 3:
          return const Color(0xFF27AE60);
        case 4:
          return PharmaTheme.emeraldGreen;
        default:
          return Colors.grey.shade300;
      }
    }

    Widget buildField({
      required TextEditingController controller,
      required String label,
      required bool obscure,
      required VoidCallback toggleObscure,
      ValueChanged<String>? onChanged,
    }) {
      return TextField(
        controller: controller,
        obscureText: obscure,
        onChanged: onChanged,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: subTextColor, fontSize: 13),
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            color: PharmaTheme.emeraldGreen,
            size: 20,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: subTextColor,
              size: 20,
            ),
            onPressed: toggleObscure,
          ),
          filled: true,
          fillColor: fieldFill,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: PharmaTheme.emeraldGreen, width: 1.5),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final newPasswordStrength = strength(newPasswordController.text);

            Future<void> handleChangePassword() async {
              final currentPassword = currentPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (currentPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                setSheetState(() => errorText = context.t('fill_all_fields'));
                return;
              }
              if (newPassword.length < 6) {
                setSheetState(
                  () => errorText = context.t('new_password_min_length'),
                );
                return;
              }
              if (newPassword != confirmPassword) {
                setSheetState(
                  () => errorText = context.t('passwords_do_not_match'),
                );
                return;
              }

              final user = _user;
              if (user == null || user.email == null) {
                setSheetState(() => errorText = context.t('not_connected'));
                return;
              }

              setSheetState(() {
                isLoading = true;
                errorText = null;
              });

              try {
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPassword,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassword);

                if (sheetContext.mounted) Navigator.pop(sheetContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.t('password_changed_successfully')),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: PharmaTheme.emeraldGreen,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                String message;
                switch (e.code) {
                  case 'wrong-password':
                  case 'invalid-credential':
                    message = context.t('current_password_incorrect');
                    break;
                  case 'weak-password':
                    message = context.t('new_password_too_weak');
                    break;
                  case 'requires-recent-login':
                    message = context.t('reconnect_and_retry');
                    break;
                  case 'too-many-requests':
                    message = context.t('too_many_attempts');
                    break;
                  default:
                    message = e.message ?? context.t('unexpected_error');
                }
                setSheetState(() {
                  isLoading = false;
                  errorText = message;
                });
              } catch (_) {
                setSheetState(() {
                  isLoading = false;
                  errorText = context.t('unexpected_error');
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: PharmaTheme.emeraldGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.shield_outlined,
                              color: PharmaTheme.emeraldGreen,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('change_password_title'),
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  context.t('change_password_subtitle'),
                                  style: TextStyle(
                                    color: subTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      buildField(
                        controller: currentPasswordController,
                        label: context.t('current_password'),
                        obscure: obscureCurrent,
                        toggleObscure: () => setSheetState(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      buildField(
                        controller: newPasswordController,
                        label: context.t('new_password'),
                        obscure: obscureNew,
                        toggleObscure: () =>
                            setSheetState(() => obscureNew = !obscureNew),
                        onChanged: (_) => setSheetState(() {}),
                      ),

                      if (newPasswordController.text.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(4, (i) {
                            final filled = i < newPasswordStrength;
                            return Expanded(
                              child: Container(
                                margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: filled
                                      ? strengthColor(newPasswordStrength)
                                      : (isDark
                                            ? Colors.white12
                                            : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],

                      const SizedBox(height: 16),
                      buildField(
                        controller: confirmPasswordController,
                        label: context.t('confirm_new_password'),
                        obscure: obscureConfirm,
                        toggleObscure: () => setSheetState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),

                      if (errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorText!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 26),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : handleChangePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PharmaTheme.emeraldGreen,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  context.t('validate'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(sheetContext),
                          child: Text(
                            context.t('cancel'),
                            style: TextStyle(color: subTextColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
