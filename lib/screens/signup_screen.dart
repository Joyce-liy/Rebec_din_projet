import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'pharmacist_hub_screen.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isObscure = true;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  double _passwordStrength(String password) {
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

  String _strengthLabel(double score) {
    switch (score.toInt()) {
      case 0:
        return "";
      case 1:
        return "Faible";
      case 2:
        return "Moyen";
      case 3:
        return "Fort";
      default:
        return "Excellent";
    }
  }

  Color _strengthColor(double score) {
    switch (score.toInt()) {
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

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnack("Veuillez remplir les champs obligatoires");
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      _showSnack("Le mot de passe doit contenir au moins 6 caractères");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      await userCredential.user?.updateDisplayName(_nameController.text.trim());
      if (!mounted) return;
      _showSnack(context.t('sign_up_success'));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PharmacistHubScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = "Un compte existe déjà avec cet email";
          break;
        case 'invalid-email':
          message = "Adresse email invalide";
          break;
        case 'weak-password':
          message = "Mot de passe trop faible";
          break;
        default:
          message = e.message ?? "Erreur lors de l'inscription";
      }
      _showSnack(message);
    } catch (_) {
      _showSnack("Une erreur est survenue");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(_passwordController.text);

    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF7),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER DÉGRADÉ ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 55, 20, 70),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [PharmaTheme.emeraldGreen, const Color(0xFF004D40)],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(40),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.local_pharmacy_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Rejoignez le réseau",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Créez votre compte pharmacien professionnel",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // --- CARTE FORMULAIRE FLOTTANTE ---
            Transform.translate(
              offset: const Offset(0, -40),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSignupField(
                      label: "NOM COMPLET",
                      hint: "Dr. Moussa Traoré",
                      icon: Icons.person_outline_rounded,
                      controller: _nameController,
                    ),
                    const SizedBox(height: 18),
                    _buildSignupField(
                      label: "EMAIL PROFESSIONNEL",
                      hint: "moussa@pharmacie.com",
                      icon: Icons.email_outlined,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    _buildSignupField(
                      label: "NUMÉRO DE LICENCE",
                      hint: "CNOP-12345",
                      icon: Icons.badge_outlined,
                      controller: _licenseController,
                    ),
                    const SizedBox(height: 18),
                    _buildSignupField(
                      label: "MOT DE PASSE",
                      hint: "••••••••",
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      controller: _passwordController,
                      onChanged: (_) => setState(() {}),
                    ),

                    if (_passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(4, (i) {
                          final filled = i < strength;
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                              height: 5,
                              decoration: BoxDecoration(
                                color: filled
                                    ? _strengthColor(strength)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _strengthLabel(strength),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _strengthColor(strength),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PharmaTheme.emeraldGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "S'INSCRIRE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                            children: [
                              const TextSpan(text: "Déjà un compte ? "),
                              TextSpan(
                                text: "Se connecter",
                                style: TextStyle(
                                  color: PharmaTheme.emeraldGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.blueGrey[700],
            fontSize: 11,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword ? _isObscure : false,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen, size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isObscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  )
                : null,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF5F8F7),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: PharmaTheme.emeraldGreen,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
