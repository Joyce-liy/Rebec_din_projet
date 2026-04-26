import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import crucial
import '../theme.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isObscure = true;
  
  // 1. Contrôleurs pour les champs
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 2. Fonction d'inscription Firebase
  Future<void> _register() async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Mettre à jour le displayName
      await userCredential.user?.updateDisplayName(_nameController.text.trim());
      // Succès : naviguer vers le hub ou dashboard
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Inscription réussie !")));
      Navigator.pop(context); 
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ... (Gardez votre Header actuel)
            
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                children: [
                  _buildSignupField(label: "Nom Complet", hint: "Dr. Moussa Traoré", icon: Icons.person_outline, controller: _nameController),
                  SizedBox(height: 20),
                  _buildSignupField(label: "Email Professionnel", hint: "moussa@pharmacie.com", icon: Icons.email_outlined, controller: _emailController, keyboardType: TextInputType.emailAddress),
                  SizedBox(height: 20),
                  _buildSignupField(label: "Numéro de Licence", hint: "CNOP-12345", icon: Icons.badge_outlined, controller: _licenseController),
                  SizedBox(height: 20),
                  _buildSignupField(label: "Mot de passe", hint: "••••••••", icon: Icons.lock_outline, isPassword: true, controller: _passwordController),
                  
                  SizedBox(height: 35),

                  // --- BOUTON S'INSCRIRE ---
                  Container(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _register, // Appel de la fonction Firebase
                      style: ElevatedButton.styleFrom(backgroundColor: PharmaTheme.emeraldGreen),
                      child: Text("S'INSCRIRE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mise à jour de la méthode pour accepter le controller
  Widget _buildSignupField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller, // Ajout
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[800], fontSize: 13)),
        SizedBox(height: 8),
        TextField(
          controller: controller, // Liaison
          obscureText: isPassword ? _isObscure : false,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: PharmaTheme.emeraldGreen, size: 22),
            hintText: hint,
            // ... (votre style actuel)
          ),
        ),
      ],
    );
  }
}