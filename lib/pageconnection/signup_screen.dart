import 'package:flutter/material.dart';
import 'package:pharma/search_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isAccepted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "S’inscrire",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Creer un compte pour trouver vos medicaments a yaounde",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SizedBox(height: 30),
            
            // Input Fields
            buildInputField(label: "Nom Complet", hint: "Votre nom", icon: Icons.person_outline),
            buildInputField(label: "Adresse Email", hint: "exemple@email.com", icon: Icons.email_outlined),
            buildInputField(label: "Mot de passe", hint: "", icon: Icons.lock_outline, isPassword: true),
            buildInputField(label: "Comfirmer mot de passe", hint: "", icon: Icons.lock_outline, isPassword: true),

            // Terms Checkbox
            Row(
              children: [
                Checkbox(
                  value: _isAccepted,
                  onChanged: (value) => setState(() => _isAccepted = value!),
                  activeColor: Colors.green,
                ),
                Expanded(
                  child: Text(
                    "J'accepte les Conditions d'utilisation et la politique de Confidentialite.",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),

            // Sign Up Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                  onPressed: () {
                  // Remplacer par votre page de Login/Home finale
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Text("S’inscrire", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),

            // Login Link
            Center(
              child: TextButton(
                onPressed: () { /* Navigate to Login */ },
                child: Text(
                  "Deja un compte? Connectez-vous",
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInputField({required String label, required String hint, required IconData icon, bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: isPassword ? Icon(Icons.visibility_outlined) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.black26),
          ),
        ),
      ),
    );
  }
}