import 'package:flutter/material.dart';
import 'package:pharma/pageconnection/signup_screen.dart';
import 'package:pharma/search_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FFF8), // Soft mint background from image
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            // Logo and App Name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/connecter.png', height: 40), // Use your mortar/pestle logo
                SizedBox(width: 10),
                Text(
                  "Pharm",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 40),
            
            Text(
              "Se Connecter",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 15),
            Text(
              "Accedez a votre compte pour trouver des pharmacies et des medicaments.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            SizedBox(height: 40),

            // Email/Username Field
            TextFormField(
              decoration: InputDecoration(
                hintText: "E-mail ou Nom d’utilisateur",
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.black12),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Password Field
            TextFormField(
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Mot de passe",
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.black12),
                ),
              ),
            ),

            // Forgot Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: Text(
                  "Mot de passe oublie?",
                  style: TextStyle(color: Color(0xFF4DB6AC)), // Teal/Mint color
                ),
              ),
            ),
            
            Spacer(), // Pushes the button towards the bottom

            // Login Button
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
                  elevation: 0,
                ),
                child: Text(
                  "Se Connecter", 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Sign Up Link
            TextButton(
               onPressed: () {
                  // Remplacer par votre page de Login/Home finale
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                  );
                },
              child: Text(
                "Pas encore de compte? S’inscrire",
                style: TextStyle(color: Colors.black87),
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}