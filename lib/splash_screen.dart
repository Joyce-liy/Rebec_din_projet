import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pharma/onboardingpages/onboarding1_screen.dart';
//import 'home_screen.dart'; // We will create this next

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // This timer waits for 3 seconds, then moves to the next screen
    Timer(Duration(seconds: 3), () {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => OnboardingScreen()),
  );
});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your Logo from the image
            Image.asset('assets/recherche.webp', width: 200),
            SizedBox(height: 20),
            // A loading indicator for a professional touch
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}