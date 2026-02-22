import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase
import 'package:pharma/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isAccepted = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _isLoading = false; // Pour afficher un indicateur de chargement

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- LOGIQUE FIREBASE D'INSCRIPTION ---
  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      if (!_isAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez accepter les conditions"), backgroundColor: Colors.redAccent),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // 1. Création du compte dans Firebase Auth
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Mise à jour du nom de l'utilisateur (DisplayName)
        await userCredential.user?.updateDisplayName(_nameController.text.trim());

        if (!mounted) return;

        // 3. Redirection vers l'accueil
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(userName: _nameController.text.trim())),
        );

      } on FirebaseAuthException catch (e) {
        String message = "Une erreur est survenue";
        if (e.code == 'weak-password') message = "Le mot de passe est trop faible.";
        else if (e.code == 'email-already-in-use') message = "Cet email est déjà utilisé.";
        else if (e.code == 'invalid-email') message = "L'adresse email n'est pas valide.";

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderIcon(),
                const SizedBox(height: 25),
                
                _buildInputField(
                  label: "Nom Complet", 
                  hint: "Ex: Joyce Doe", 
                  icon: Icons.person_outline,
                  controller: _nameController,
                ),
                _buildInputField(
                  label: "Adresse Email", 
                  hint: "exemple@email.com", 
                  icon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                _buildInputField(
                  label: "Mot de passe", 
                  icon: Icons.lock_outline,
                  isPassword: true,
                  isObscured: !_isPasswordVisible,
                  controller: _passwordController,
                  toggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  validator: (v) => v!.length < 6 ? "Minimum 6 caractères" : null,
                ),
                _buildInputField(
                  label: "Confirmer", 
                  icon: Icons.lock_reset_outlined,
                  isPassword: true,
                  isObscured: !_isConfirmVisible,
                  controller: _confirmPasswordController,
                  toggleVisibility: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
                  validator: (value) => value != _passwordController.text ? "Les mots de passe ne correspondent pas" : null,
                ),

                _buildCheckbox(),
                const SizedBox(height: 25),

                // --- BOUTON D'INSCRIPTION AVEC LOADING ---
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("S’inscrire maintenant", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),

                const SizedBox(height: 15),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE COMPOSANTS ---

  Widget _buildHeaderIcon() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.person_add_rounded, color: Colors.green, size: 40),
          ),
          const SizedBox(height: 15),
          const Text("Créer un compte", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const Text("Rejoignez la communauté PharmaYaoundé", style: TextStyle(fontSize: 14, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _isAccepted,
          onChanged: (value) => setState(() => _isAccepted = value!),
          activeColor: Colors.green,
        ),
        const Expanded(
          child: Text("J'accepte les Conditions et la Politique de Confidentialité.", style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        child: RichText(
          text: TextSpan(
            text: "Déjà un compte ? ",
            style: const TextStyle(color: Colors.black54, fontSize: 14),
            children: [
              TextSpan(
                text: "Connexion",
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label, 
    String? hint, 
    required IconData icon, 
    bool isPassword = false,
    bool isObscured = false,
    TextEditingController? controller,
    VoidCallback? toggleVisibility,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: isObscured,
            keyboardType: keyboardType,
            validator: validator ?? (value) => value!.isEmpty ? "Obligatoire" : null,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: Colors.green.shade600, size: 20),
              suffixIcon: isPassword 
                ? IconButton(icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility), onPressed: toggleVisibility)
                : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green)),
            ),
          ),
        ],
      ),
    );
  }
}