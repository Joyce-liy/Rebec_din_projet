import 'package:flutter/material.dart';
import 'package:pharma/home_screen.dart';
import 'package:pharma/pageconnection/signup_screen.dart';

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

  // Simulation d'une connexion pour le côté professionnel
  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Simulation d'un délai réseau
      await Future.delayed(const Duration(seconds: 1));

      String name = _userController.text.trim();
      if (name.contains('@')) {
        name = name.split('@')[0];
      }
      if (name.isEmpty) name = "Joyce";

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
      backgroundColor: Colors.white, // Fond blanc pur plus moderne
      body: SafeArea(
        child: CustomScrollView( // Permet le scroll si le contenu dépasse (petits écrans)
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildWelcomeText(),
                      const SizedBox(height: 50),
                      
                      // Champ Email / User
                      _buildTextField(
                        controller: _userController,
                        hint: "E-mail ou Nom d’utilisateur",
                        icon: Icons.person_outline,
                        validator: (value) => value!.isEmpty ? "Champ obligatoire" : null,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Champ Mot de passe
                      _buildTextField(
                        controller: _passwordController,
                        hint: "Mot de passe",
                        icon: Icons.lock_outline,
                        isPassword: true,
                        validator: (value) => value!.length < 6 ? "Minimum 6 caractères" : null,
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            "Mot de passe oublié ?",
                            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Bouton de connexion avec état de chargement
                      _buildLoginButton(),
                      
                      const SizedBox(height: 15),
                      
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

  // --- WIDGETS DE COMPOSANTS ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.medical_services, color: Colors.green, size: 30),
        ),
        const SizedBox(width: 12),
        const Text(
          "PharmConnect",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        const Text(
          "Bon retour parmi nous !",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          "Connectez-vous pour gérer vos médicaments.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            )
          : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Color(0xFF00E676)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
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
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          shadowColor: Colors.green.withOpacity(0.3),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              "Se Connecter",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Nouveau ici ? "),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())),
          child: Text(
            "Créer un compte",
            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}