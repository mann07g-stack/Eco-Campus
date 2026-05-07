import "package:flutter/material.dart";
import "package:dio/dio.dart";

import "../models/auth_session.dart";
import "../services/api_service.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final void Function(AuthSession session) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _registerName = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPhone = TextEditingController();
  final _registerCampus = TextEditingController(text: "MAIN-CAMPUS");
  final _registerPassword = TextEditingController();
  bool _loading = false;
  bool _registering = false;
  String _error = "";
  String _mode = "login";
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _email.dispose();
    _password.dispose();
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPhone.dispose();
    _registerCampus.dispose();
    _registerPassword.dispose();
    super.dispose();
  }

  String _formatError(Object error, {required String fallback}) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;
      String serverMessage = "";

      if (responseData is Map<String, dynamic>) {
        final msg = responseData["message"] ?? responseData["error"];
        if (msg != null) {
          serverMessage = msg.toString();
        }
      } else if (responseData != null) {
        serverMessage = responseData.toString();
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return "Cannot reach API. Check that backend is running and your device can connect.";
      }

      if (statusCode != null) {
        if (serverMessage.isNotEmpty) {
          return "Request failed ($statusCode): $serverMessage";
        }
        return "Request failed with status $statusCode.";
      }

      if (serverMessage.isNotEmpty) {
        return serverMessage;
      }
    }

    return fallback;
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final res = await ApiService.instance.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      widget.onLoggedIn(AuthSession.fromJson(res.data["user"] as Map<String, dynamic>));
    } catch (error) {
      setState(() => _error = _formatError(error, fallback: "Login failed. Please verify credentials."));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _register() async {
    setState(() {
      _registering = true;
      _error = "";
    });

    try {
      await ApiService.instance.registerStudent(
        fullName: _registerName.text.trim(),
        email: _registerEmail.text.trim(),
        phone: _registerPhone.text.trim(),
        campusId: _registerCampus.text.trim(),
        password: _registerPassword.text,
      );
      if (!mounted) return;
      setState(() {
        _mode = "login";
        _password.clear();
        _error = "Account created. You can log in now.";
      });
    } catch (error) {
      setState(() => _error = _formatError(error, fallback: "Registration failed. Please check the details."));
    } finally {
      if (mounted) {
        setState(() => _registering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF081A1F), Color(0xFF0B5D5F), Color(0xFF0E7490)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
              ),
              child: Column(
                children: [
                  // Logo & Branding Section
                  SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
                      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
                    ),
                    child: Column(
                      children: [
                        // Animated Recycling Icon
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF4A259).withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2.5),
                            ),
                            child: const Icon(
                              Icons.recycling,
                              size: 60,
                              color: Color(0xFFF4A259),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "ECO CAMPUS",
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Smart E-Waste Management System",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB0E7E0),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 45),
                  // Mode Selector - Beautiful Custom Design
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        _buildModeButton("SIGN IN", "login", Icons.login_rounded),
                        _buildModeButton("REGISTER", "register", Icons.app_registration_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Form Content with Animation
                  SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(
                      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _mode == "login" ? _buildLoginForm() : _buildRegisterForm(),
                    ),
                  ),
                  // Error Display
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        border: Border.all(color: Colors.red.withOpacity(0.4), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Footer Message
                  Text(
                    "♻️ Reduce • Reuse • Recycle ♻️",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1,
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

  Widget _buildModeButton(String label, String mode, IconData icon) {
    final isSelected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF4A259) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFF4A259).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: isSelected ? Colors.black87 : Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.black87 : Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey("login"),
      children: [
        _buildCustomTextField(
          controller: _email,
          label: "Email Address",
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _buildCustomTextField(
          controller: _password,
          label: "Password",
          icon: Icons.lock_rounded,
          obscureText: true,
          onSubmitted: (_) => _loading ? null : _login(),
        ),
        const SizedBox(height: 28),
        // Sign In Button with Gradient
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF4A259), Color(0xFFE89A4C)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF4A259).withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.black87),
                    ),
                  )
                : const Text(
                    "SIGN IN",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey("register"),
      children: [
        _buildCustomTextField(
          controller: _registerName,
          label: "Full Name",
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 14),
        _buildCustomTextField(
          controller: _registerEmail,
          label: "Email Address",
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildCustomTextField(
          controller: _registerPhone,
          label: "Phone Number",
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),
        _buildCustomTextField(
          controller: _registerCampus,
          label: "Campus ID",
          icon: Icons.location_city_rounded,
        ),
        const SizedBox(height: 14),
        _buildCustomTextField(
          controller: _registerPassword,
          label: "Password",
          icon: Icons.lock_rounded,
          obscureText: true,
          onSubmitted: (_) => _registering ? null : _register(),
        ),
        const SizedBox(height: 28),
        // Register Button with Gradient
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B5D5F), Color(0xFF0E7490)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0B5D5F).withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _registering ? null : _register,
            child: _registering
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text(
                    "CREATE ACCOUNT",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFFF4A259), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
        cursorColor: const Color(0xFFF4A259),
      ),
    );
  }
}
