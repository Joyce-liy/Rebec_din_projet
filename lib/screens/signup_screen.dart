import 'package:flutter/material.dart';
import '../theme.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER AVEC DÉGRADÉ ---
            Stack(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [PharmaTheme.emeraldGreen, Color(0xFF004D40)],
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      Text(
                        "Créer un Compte",
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Rejoignez le réseau des pharmaciens",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  // --- CHAMPS DE SAISIE ---
                  _buildSignupField(
                    label: "Nom Complet",
                    hint: "Dr. Moussa Traoré",
                    icon: Icons.person_outline,
                  ),
                  SizedBox(height: 20),

                  _buildSignupField(
                    label: "Email Professionnel",
                    hint: "moussa@pharmacie.com",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 20),

                  _buildSignupField(
                    label: "Numéro de Licence / Ordre",
                    hint: "CNOP-12345",
                    icon: Icons.badge_outlined,
                  ),
                  SizedBox(height: 20),

                  _buildSignupField(
                    label: "Mot de passe",
                    hint: "••••••••",
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),

                  SizedBox(height: 35),

                  // --- BOUTON S'INSCRIRE ---
                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [PharmaTheme.emeraldGreen, Color(0xFF00695C)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: PharmaTheme.emeraldGreen.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 5))
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        // Logique d'inscription
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text("S'INSCRIRE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),

                  SizedBox(height: 25),

                  // --- LIEN VERS CONNEXION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Déjà inscrit ?"),
                      TextButton(
                        onPressed: () => Navigator.pop(context), // Retour au login
                        child: Text("Se connecter",
                            style: TextStyle(color: PharmaTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget réutilisable pour les champs
  Widget _buildSignupField({
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800], fontSize: 13)),
        SizedBox(height: 8),
        TextField(
          obscureText: isPassword ? _isObscure : false,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen, size: 22),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _isObscure = !_isObscure),
            )
                : null,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: Color(0xFFF8F9FA),
            contentPadding: EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey[100]!, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}