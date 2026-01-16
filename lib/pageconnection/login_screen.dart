import 'package:flutter/material.dart';
import 'package:pharma/home_screen.dart';
import 'package:pharma/pageconnection/signup_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final String? userName;
  const LoginScreen({super.key, this.userName});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
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

  // --- LOGIQUE POUR SAUTER ONBOARDING ET LOGIN ---
  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // On vérifie si l'utilisateur est déjà connecté
    final bool? isLoggedIn = prefs.getBool('is_logged_in');
    final String? savedUser = prefs.getString('user_name');

    // Tentative Google Silencieuse
    final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

    if (googleUser != null) {
      _completeLogin(googleUser.displayName ?? "Utilisateur");
    } else if (isLoggedIn == true && savedUser != null) {
      _completeLogin(savedUser);
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Cette fonction sauvegarde tout et redirige
  Future<void> _completeLogin(String name) async {
    final prefs = await SharedPreferences.getInstance();
    
    // On marque que l'utilisateur est connecté ET qu'il a passé l'onboarding
    await prefs.setString('user_name', name);
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('seen_onboarding', true); // Empêche de revoir l'onboarding

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(userName: name)),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        await _completeLogin(googleUser.displayName ?? "Utilisateur");
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

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1)); 
      
      String name = _userController.text.trim();
      await _completeLogin(name);
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
                        controller: _userController,
                        hint: "E-mail ou Utilisateur",
                        icon: Icons.person_outline,
                        validator: (v) => v!.isEmpty ? "Obligatoire" : null,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        hint: "Mot de passe",
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: (v) => v!.length < 6 ? "Trop court" : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
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

  // --- WIDGETS DE STYLE (Gardés tels quels) ---
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

  Widget _buildGoogleButton() => SizedBox(width: double.infinity, height: 56, child: OutlinedButton(onPressed: _isLoading ? null : _handleGoogleSignIn, style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Image.network('https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png', height: 24), const SizedBox(width: 12), const Text("Continuer avec Google", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))])));

  Widget _buildFooter() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Pas de compte ? "), GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())), child: const Text("S'inscrire", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))]);
}