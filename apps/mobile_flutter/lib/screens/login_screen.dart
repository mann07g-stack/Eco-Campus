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

class _LoginScreenState extends State<LoginScreen> {
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
            colors: [Color(0xFF081A1F), Color(0xFF0B5D5F), Color(0xFFF4A259)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 20,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Eco Campus", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text("Student registration and member access", style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 20),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: "login", label: Text("Sign In"), icon: Icon(Icons.login)),
                            ButtonSegment(value: "register", label: Text("Create Student"), icon: Icon(Icons.school)),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (value) => setState(() => _mode = value.first),
                        ),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _mode == "login" ? _buildLoginForm() : _buildRegisterForm(),
                        ),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(_error, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      key: const ValueKey("login"),
      children: [
        TextField(
          controller: _email,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email_outlined)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _loading ? null : _login(),
          decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Log In"),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      key: const ValueKey("register"),
      children: [
        TextField(controller: _registerName, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: "Full name", prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 12),
        TextField(controller: _registerEmail, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: "Student email", prefixIcon: Icon(Icons.email_outlined))),
        const SizedBox(height: 12),
        TextField(controller: _registerPhone, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: "Phone number", prefixIcon: Icon(Icons.call_outlined))),
        const SizedBox(height: 12),
        TextField(controller: _registerCampus, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: "Campus ID", prefixIcon: Icon(Icons.location_city_outlined))),
        const SizedBox(height: 12),
        TextField(
          controller: _registerPassword,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _registering ? null : _register(),
          decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock_outline)),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            onPressed: _registering ? null : _register,
            child: _registering
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Create Student Account"),
          ),
        ),
      ],
    );
  }
}
