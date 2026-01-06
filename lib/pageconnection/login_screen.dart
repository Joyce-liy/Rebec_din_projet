import 'package:flutter/material.dart';
import 'package:pharma/home_screen.dart';
import 'package:pharma/pageconnection/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  // CORRECTION : userName est désormais optionnel (?) pour éviter les erreurs de compilation ailleurs
  final String? userName; 
  const LoginScreen({super.key, this.userName});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Contrôleur pour récupérer le nom ou l'email
  final TextEditingController _userController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Si un nom a été passé (ex: après une inscription), on l'affiche par défaut
    if (widget.userName != null) {
      _userController.text = widget.userName!;
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF8),
      // resizeToAvoidBottomInset empêche le clavier de casser le design
      resizeToAvoidBottomInset: false, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/connecter.png', 
                  height: 40, 
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.medical_services, color: Colors.green)
                ), 
                const SizedBox(width: 10),
                const Text("Pharm", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 40),
            const Text("Se Connecter", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text(
              "Accédez à votre compte pour trouver des pharmacies et des médicaments.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 40),

            // Champ Utilisateur
            TextFormField(
              controller: _userController,
              decoration: InputDecoration(
                hintText: "E-mail ou Nom d’utilisateur",
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Champ Mot de passe
            TextFormField(
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Mot de passe",
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text("Mot de passe oublié ?", style: TextStyle(color: Color(0xFF4DB6AC))),
              ),
            ),
            
            const Spacer(),

            // Bouton de connexion
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  String name = _userController.text.trim();
                  
                  // Valeur par défaut si vide
                  if (name.isEmpty) {
                    name = "Joyce"; 
                  } else if (name.contains('@')) {
                    // Si c'est un email, on ne garde que la partie avant le @ pour le message "Hello"
                    name = name.split('@')[0];
                  }

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomeScreen(userName: name)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text("Se Connecter", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),

            TextButton(
               onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
              child: const Text("Pas encore de compte? S’inscrire", style: TextStyle(color: Colors.black87)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}