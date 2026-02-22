import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pharma/search_screen.dart';
import 'package:pharma/theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  bool _isAccepted = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Focus states
  bool _nameFocused = false;
  bool _emailFocused = false;
  bool _passwordFocused = false;
  bool _confirmFocused = false;

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      if (!_isAccepted) {
        _showErrorSnackBar("Veuillez accepter les conditions d'utilisation");
        return;
      }

      setState(() => _isLoading = true);

      try {
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await userCredential.user
            ?.updateDisplayName(_nameController.text.trim());

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SearchScreen(onSearchFocusChanged: (_) {}),
          ),
        );
      } on FirebaseAuthException catch (e) {
        String message = "Une erreur est survenue";
        if (e.code == 'weak-password') {
          message = "Le mot de passe est trop faible.";
        } else if (e.code == 'email-already-in-use') {
          message = "Cet email est déjà utilisé.";
        } else if (e.code == 'invalid-email') {
          message = "L'adresse email n'est pas valide.";
        }

        _showErrorSnackBar(message);
      } catch (e) {
        _showErrorSnackBar("Erreur: ${e.toString()}");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFFF0FDF4),
              Color(0xFFFAFAFA),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Header
                  _buildHeader(),
                  
                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            _buildHeaderSection(),
                            const SizedBox(height: 32),
                            _buildInputField(
                              label: "Nom complet",
                              hint: "Ex: Joyce Doe",
                              icon: Icons.person_outline_rounded,
                              controller: _nameController,
                              isFocused: _nameFocused,
                              onFocusChange: (f) =>
                                  setState(() => _nameFocused = f),
                            ),
                            _buildInputField(
                              label: "Adresse email",
                              hint: "exemple@email.com",
                              icon: Icons.email_outlined,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              isFocused: _emailFocused,
                              onFocusChange: (f) =>
                                  setState(() => _emailFocused = f),
                            ),
                            _buildInputField(
                              label: "Mot de passe",
                              hint: "Minimum 6 caractères",
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              isObscured: !_isPasswordVisible,
                              controller: _passwordController,
                              toggleVisibility: () => setState(
                                  () => _isPasswordVisible = !_isPasswordVisible),
                              validator: (v) =>
                                  v!.length < 6 ? "Minimum 6 caractères" : null,
                              isFocused: _passwordFocused,
                              onFocusChange: (f) =>
                                  setState(() => _passwordFocused = f),
                            ),
                            _buildInputField(
                              label: "Confirmer le mot de passe",
                              hint: "Répétez votre mot de passe",
                              icon: Icons.lock_reset_rounded,
                              isPassword: true,
                              isObscured: !_isConfirmVisible,
                              controller: _confirmPasswordController,
                              toggleVisibility: () => setState(
                                  () => _isConfirmVisible = !_isConfirmVisible),
                              validator: (value) =>
                                  value != _passwordController.text
                                      ? "Les mots de passe ne correspondent pas"
                                      : null,
                              isFocused: _confirmFocused,
                              onFocusChange: (f) =>
                                  setState(() => _confirmFocused = f),
                            ),
                            const SizedBox(height: 8),
                            _buildCheckbox(),
                            const SizedBox(height: 32),
                            _buildSignupButton(),
                            const SizedBox(height: 24),
                            _buildFooter(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.soft,
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.slate600,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  "Connexion sécurisée",
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 24),
        
        // Title
        Text(
          "Créer un compte",
          style: AppTypography.displaySmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        
        // Subtitle
        Text(
          "Rejoignez la communauté PharmConnect",
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.slate500,
          ),
        ),
      ],
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
    required bool isFocused,
    required ValueChanged<bool> onFocusChange,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.slate700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Focus(
            onFocusChange: onFocusChange,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: TextFormField(
                controller: controller,
                obscureText: isObscured,
                keyboardType: keyboardType,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.slate800,
                ),
                validator: validator ??
                    (value) => value!.isEmpty ? "Ce champ est requis" : null,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.slate400,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(
                      icon,
                      color: isFocused ? AppColors.primary : AppColors.slate400,
                      size: 22,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0),
                  suffixIcon: isPassword
                      ? IconButton(
                          icon: Icon(
                            isObscured
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.slate400,
                            size: 22,
                          ),
                          onPressed: toggleVisibility,
                        )
                      : null,
                  filled: true,
                  fillColor: isFocused ? Colors.white : AppColors.slate50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.slate200,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.error,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _isAccepted = !_isAccepted),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _isAccepted
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.slate50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isAccepted ? AppColors.primary.withOpacity(0.3) : AppColors.slate200,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: _isAccepted ? AppColors.primaryGradient : null,
                color: _isAccepted ? null : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isAccepted ? Colors.transparent : AppColors.slate300,
                  width: 1.5,
                ),
                boxShadow: _isAccepted
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: _isAccepted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "J'accepte les Conditions d'utilisation et la Politique de Confidentialité",
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.slate600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupButton() {
    return GradientButton(
      text: "Créer mon compte",
      onPressed: _isLoading ? null : _handleSignup,
      isLoading: _isLoading,
      icon: Icons.person_add_rounded,
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Déjà un compte ? ",
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.slate500,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                "Se connecter",
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}