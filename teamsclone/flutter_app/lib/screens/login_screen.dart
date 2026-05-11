import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isRegister = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    try {
      if (_isRegister) {
        await auth.register(_nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
      } else {
        await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(AppColors.primaryColor),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 5))],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_rounded, size: 64, color: const Color(AppColors.primaryColor)),
                  const SizedBox(height: 12),
                  const Text('TeamsClone', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text(_isRegister ? 'Create your account' : 'Welcome back', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 32),
                  if (_isRegister)
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  if (_isRegister) const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: auth.loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppColors.primaryColor),
                        foregroundColor: Colors.white,
                      ),
                      child: auth.loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isRegister ? 'Sign Up' : 'Log In'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _isRegister = !_isRegister),
                    child: Text(_isRegister ? 'Already have an account? Log in' : 'No account? Sign up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
