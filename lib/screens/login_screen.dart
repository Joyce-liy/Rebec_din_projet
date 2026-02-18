import 'package:flutter/material.dart';
import 'package:pharm_admin/screens/signup_screen.dart';
import '../theme.dart';
import 'pharmacist_hub_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER DESIGN ---
            Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [PharmaTheme.emeraldGreen, Color(0xFF004D40)],
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_person_rounded, size: 80, color: Colors.white),
                    SizedBox(height: 10),
                    Text("Connexion Admin",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CHAMPS DE SAISIE ---
                  _buildLabel("Nom d'utilisateur"),
                  _buildTextField(hint: "Ex: Dr. Diallo", icon: Icons.person_outline),

                  SizedBox(height: 20),

                  _buildLabel("Mot de passe"),
                  _buildTextField(
                    hint: "••••••••",
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),

                  // --- MOT DE PASSE OUBLIÉ ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text("Mot de passe oublié ?",
                          style: TextStyle(color: PharmaTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  SizedBox(height: 20),

                  // --- BOUTON CONFIRMER ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PharmacistHubScreen()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PharmaTheme.emeraldGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: Text("CONFIRMER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),

                  SizedBox(height: 30),

                  // --- SÉPARATEUR OU ---
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text("OU", style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),

                  SizedBox(height: 30),

                  // --- BOUTON GOOGLE ---
                  OutlinedButton(
                    onPressed: () {
                      // Ici la logique Google Sign-In
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 55),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_\"G\"_logo.svg/1200px-Google_\"G\"_logo.svg.png', height: 24),
                        SizedBox(width: 15),
                        Text("Continuer avec Google", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // --- CRÉER UN COMPTE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Nouveau pharmacien ?"),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SignupScreen()),
                          );
                        },
                        child: Text("Créer un compte",
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

  // Widget pour les labels
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
    );
  }

  // Widget pour les champs textes
  Widget _buildTextField({required String hint, required IconData icon, bool isPassword = false}) {
    return TextField(
      obscureText: isPassword ? _isObscure : false,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _isObscure = !_isObscure),
        )
            : null,
        hintText: hint,
        filled: true,
        fillColor: Color(0xFFF5F7F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}