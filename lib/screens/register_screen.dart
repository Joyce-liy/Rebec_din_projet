import 'package:flutter/material.dart';
import 'package:pharm_admin/screens/pharmacist_hub_screen.dart';
import '../theme.dart';

class RegisterScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_pharmacy, size: 80, color: PharmaTheme.emeraldGreen),
            SizedBox(height: 20),
            Text("Rejoignez le Réseau", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 30),
            TextField(decoration: InputDecoration(labelText: "Nom complet", border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            SizedBox(height: 15),
            TextField(obscureText: true, decoration: InputDecoration(labelText: "Mot de passe", border: OutlineInputBorder())),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => PharmacistHubScreen())
                    );
                  }, child: Text("S'INSCRIRE")),
            ),
          ],
        ),
      ),
    );
  }
}