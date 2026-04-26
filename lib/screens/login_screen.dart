import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pharm_admin/screens/signup_screen.dart';
import '../theme.dart';
import 'pharmacist_hub_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Fonction connexion Email/Password
  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PharmacistHubScreen()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Erreur de connexion")),
      );
    }
  }

  // Fonction connexion Google - LOGIQUE AJOUTÉE
  Future<void> _signInWithGoogle() async {
    try {
      // 1. Connexion Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return; // Utilisateur a annulé

      // 2. Récupération des tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Création du credential Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Connexion Firebase
      await _auth.signInWithCredential(credential);

      // 5. Redirection
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => PharmacistHubScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur Google : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [PharmaTheme.emeraldGreen, Color(0xFF004D40)],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(50),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_person_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Connexion Admin",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Email Professionnel"),
                  _buildTextField(
                    hint: "Ex: docteur@pharmacie.com",
                    icon: Icons.email_outlined,
                    controller: _emailController,
                  ),
                  SizedBox(height: 20),
                  _buildLabel("Mot de passe"),
                  _buildTextField(
                    hint: "••••••••",
                    icon: Icons.lock_outline,
                    isPassword: true,
                    controller: _passwordController,
                  ),

                  SizedBox(height: 20),

                  // Bouton Confirmer
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PharmaTheme.emeraldGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        "CONFIRMER",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Séparateur OU
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text("OU"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Bouton Google
                  OutlinedButton(
                    onPressed: _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Continuer avec Google",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),

                  // Lien Inscription
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Nouveau pharmacien ?"),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignupScreen(),
                          ),
                        ),
                        child: Text(
                          "Créer un compte",
                          style: TextStyle(
                            color: PharmaTheme.emeraldGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey[800],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _isObscure : false,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            : null,
        hintText: hint,
        filled: true,
        fillColor: Color(0xFFF5F7F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
