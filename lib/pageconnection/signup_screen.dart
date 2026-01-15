import 'package:flutter/material.dart';
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

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignup() {
    if (_formKey.currentState!.validate()) {
      if (!_isAccepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Veuillez accepter les conditions"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen(userName: _nameController.text.trim())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 18),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
          ),
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
                // --- ICON ET TITRE ---
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_add_rounded, color: Colors.green, size: 40),
                      ),
                      const SizedBox(height: 15),
                      const Text("Créer un compte", 
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      const Text("Rejoignez la communauté PharmaYaoundé", 
                        style: TextStyle(fontSize: 14, color: Colors.black54)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 25), // Espacement réduit
                
                // --- CHAMPS DE SAISIE ---
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
                ),
                _buildInputField(
                  label: "Confirmer", 
                  icon: Icons.lock_reset_outlined,
                  isPassword: true,
                  isObscured: !_isConfirmVisible,
                  controller: _confirmPasswordController,
                  toggleVisibility: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
                  validator: (value) {
                    if (value != _passwordController.text) return "Incohérent";
                    return null;
                  },
                ),

                // --- CHECKBOX ---
                Row(
                  children: [
                    SizedBox(
                      height: 24, width: 24,
                      child: Checkbox(
                        value: _isAccepted,
                        onChanged: (value) => setState(() => _isAccepted = value!),
                        activeColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "J'accepte les Conditions et la Politique de Confidentialité.", 
                        style: TextStyle(fontSize: 11, color: Colors.black87)
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 25),

                // --- BOUTON S'INSCRIRE ---
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text("S’inscrire maintenant", 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 15),

                // --- LIEN VERS CONNEXION ---
                Center(
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
                ),
                const SizedBox(height: 20),
              ],
            ),
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
      padding: const EdgeInsets.only(bottom: 15), // Espacement réduit entre champs
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: isObscured,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15),
            validator: validator ?? (value) => value!.isEmpty ? "Obligatoire" : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.green.shade600, size: 20),
              suffixIcon: isPassword 
                ? IconButton(
                    icon: Icon(isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    onPressed: toggleVisibility,
                  )
                : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.green, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}