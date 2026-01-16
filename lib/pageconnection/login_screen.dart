import 'package:flutter/material.dart';
import 'package:pharma/home_screen.dart';
import 'package:pharma/pageconnection/signup_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  bool _isLoading = false;

  // Couleur pour les bordures
  final Color _lightGreenBorder = const Color(0xFFB9F6CA);

  // Configuration Google Sign-In
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  @override
  void initState() {
    super.initState();
    if (widget.userName != null) {
      _userController.text = widget.userName!;
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userName: googleUser.displayName ?? "Utilisateur"),
          ),
        );
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
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(userName: name)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      
                      // Champ Email / Utilisateur
                      _buildTextField(
                        controller: _userController,
                        hint: "E-mail ou Utilisateur",
                        icon: Icons.person_outline,
                        validator: (v) => v!.isEmpty ? "Obligatoire" : null,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Champ Mot de passe
                      _buildTextField(
                        controller: _passwordController,
                        hint: "Mot de passe",
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: (v) => v!.length < 6 ? "Trop court" : null,
                      ),

                      // --- OPTION MOT DE PASSE OUBLIÉ ---
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // Ajouter votre navigation vers la page de récupération ici
                          },
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.medical_services, color: Colors.green, size: 30),
        ),
        const SizedBox(width: 12),
        const Text("PharmConnect", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return const Column(
      children: [
        Text("Bienvenue", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text("Connectez-vous pour continuer", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, bool isPassword = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green),
        suffixIcon: isPassword ? IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ) : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        // --- BORDURES VERT CLAIR ---
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: _lightGreenBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : const Text("Se Connecter", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      const Expanded(child: Divider()),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Text("OU", style: TextStyle(color: Colors.grey.shade400))),
      const Expanded(child: Divider()),
    ]);
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Utilisation d'une image pour le vrai logo Google coloré
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
              height: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              "Continuer avec Google",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Pas de compte ? "),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
          child: const Text("S'inscrire", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}