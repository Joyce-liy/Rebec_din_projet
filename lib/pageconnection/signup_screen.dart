import 'package:flutter/material.dart';
import 'package:pharma/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isAccepted = false;
  // Contrôleur pour le champ nom
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("S’inscrire", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Creer un compte pour trouver vos medicaments a yaounde", style: TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 30),
            
            // On passe le contrôleur ici
            buildInputField(
              label: "Nom Complet", 
              hint: "Votre nom", 
              icon: Icons.person_outline,
              controller: _nameController, 
            ),
            buildInputField(label: "Adresse Email", hint: "exemple@email.com", icon: Icons.email_outlined),
            buildInputField(label: "Mot de passe", hint: "", icon: Icons.lock_outline, isPassword: true),
            buildInputField(label: "Comfirmer mot de passe", hint: "", icon: Icons.lock_outline, isPassword: true),

            Row(
              children: [
                Checkbox(
                  value: _isAccepted,
                  onChanged: (value) => setState(() => _isAccepted = value!),
                  activeColor: Colors.green,
                ),
                const Expanded(
                  child: Text("J'accepte les Conditions d'utilisation et la politique de Confidentialite.", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  // RÉCUPÉRATION DU NOM
                  String name = _nameController.text.trim();
                  if (name.isEmpty) name = "Nouvel Utilisateur";

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen(userName: name)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("S’inscrire", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ),

            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Deja un compte? Connectez-vous", style: TextStyle(color: Colors.black87)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fonction buildInputField mise à jour pour accepter un controller
  Widget buildInputField({
    required String label, 
    required String hint, 
    required IconData icon, 
    bool isPassword = false,
    TextEditingController? controller, // AJOUT DU CONTROLLER ICI
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller, // LIEN AVEC LE CONTROLLER
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: isPassword ? const Icon(Icons.visibility_outlined) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.black26),
          ),
        ),
      ),
    );
  }
}