import 'package:flutter/material.dart';
import 'package:pharma/home_screen.dart';
import 'package:pharma/pageconnection/signup_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase

class LoginScreen extends StatefulWidget {
  final String? userName;
  const LoginScreen({super.key, this.userName});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController(); // Renommé pour clarté
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance; // Instance Firebase
  
  bool _isPasswordVisible = false;
  bool _isLoading = true; 

  final Color _lightGreenBorder = const Color(0xFFB9F6CA);

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  @override
  void initState() {
    super.initState();
    _checkExistingSession(); 
  }

  // --- VÉRIFICATION DE LA SESSION ---
  Future<void> _checkExistingSession() async {
    // Vérification Firebase d'abord (plus fiable)
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      _completeLogin(currentUser.displayName ?? "Utilisateur");
    } else {
      // Si Firebase n'a pas de session, on check Google en silencieux
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        _completeLogin(googleUser.displayName ?? "Utilisateur");
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Sauvegarde locale et redirection
  Future<void> _completeLogin(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('seen_onboarding', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(userName: name)),
    );
  }

  // --- CONNEXION GOOGLE ---
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        // On lie Google à Firebase
        UserCredential userCredential = await _auth.signInWithCredential(credential);
        await _completeLogin(userCredential.user?.displayName ?? "Utilisateur");
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur Google : $error"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- CONNEXION EMAIL/PASSWORD (FIREBASE) ---
  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        // Authentification réelle avec Firebase
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Récupération du nom (displayName) ou utilisation de l'email par défaut
        String name = userCredential.user?.displayName ?? 
                     _emailController.text.split('@')[0];
        
        await _completeLogin(name);
        
      } on FirebaseAuthException catch (e) {
        String message = "Une erreur est survenue";
        if (e.code == 'user-not-found') message = "Aucun utilisateur trouvé pour cet email.";
        else if (e.code == 'wrong-password') message = "Mot de passe incorrect.";
        else if (e.code == 'invalid-email') message = "Format d'email invalide.";

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildWelcomeText(),
                      const SizedBox(height: 40),
                      _buildTextField(
                        controller: _emailController,
                        hint: "Email",
                        icon: Icons.email_outlined,
                        validator: (v) => v!.isEmpty || !v.contains('@') ? "Email invalide" : null,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        hint: "Mot de passe",
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: (v) => v!.length < 6 ? "Minimum 6 caractères" : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () { /* Ajouter logique Reset Password ici */ },
                          child: Text(
                            "Mot de passe oublié ?",
                            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildLoginButton(),
                      const SizedBox(height: 25),
                      _buildDivider(),
                      const SizedBox(height: 25),
                      _buildGoogleButton(),
                      const Spacer(),
                      _buildFooter(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE STYLE ---
  Widget _buildHeader() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.medical_services, color: Colors.green, size: 30)),
    const SizedBox(width: 12),
    const Text("PharmConnect", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
  ]);

  Widget _buildWelcomeText() => const Column(children: [
    Text("Bienvenue", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    SizedBox(height: 8),
    Text("Connectez-vous pour continuer", style: TextStyle(color: Colors.grey)),
  ]);

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, bool isPassword = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      validator: validator,
      keyboardType: isPassword ? TextInputType.text : TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green),
        suffixIcon: isPassword ? IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)) : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _lightGreenBorder, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.green, width: 2)),
      ),
    );
  }

  Widget _buildLoginButton() => SizedBox(width: double.infinity, height: 56, child: ElevatedButton(onPressed: _isLoading ? null : _handleLogin, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("Se Connecter", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))));

  Widget _buildDivider() => Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Text("OU", style: TextStyle(color: Colors.grey.shade400))), const Expanded(child: Divider())]);

  Widget _buildGoogleButton() => SizedBox(
      width: double.infinity, 
      height: 48, 
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ajout de la virgule ici après l'image
            Image.asset('assets/google.png', height: 22), 
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                "Continuer avec Google",
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

  Widget _buildFooter() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Pas de compte ? "), GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())), child: const Text("S'inscrire", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))]);
}