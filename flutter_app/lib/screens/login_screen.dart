import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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
  bool _obscurePass = true;

  static const Color _primary = Color(0xFFA10000);
  static const Color _primaryDark = Color(0xFF650000);
  static const Color _dark = Color(0xFF171717);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _field = Color(0xFFF5F5F7);
  static const Color _textDark = Color(0xFF202020);
  static const Color _textMuted = Color(0xFF8D8D8D);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    try {
      if (_isRegister) {
        await auth.register(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
      } else {
        await auth.login(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  e.toString().replaceAll('Exception: ', ''),
                ),
              ),
            ],
          ),
          backgroundColor: _dark,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _dark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 700;

          return Stack(
            children: [
              const _AuthBackground(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 32 : 22,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: _buildAuthCard(auth),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuthCard(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 40,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryDark, _primary, Color(0xFFE02020)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    children: [
                      _buildBrandHeader(),
                      const SizedBox(height: 24),
                      _buildModeSwitch(),
                      const SizedBox(height: 26),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Column(
                          key: ValueKey(_isRegister),
                          children: [
                            Text(
                              _isRegister ? 'Create Account' : 'Welcome Back',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: _textDark,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isRegister
                                  ? 'Join your TelexPH company workspace.'
                                  : 'Sign in to continue to your workspace.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _isRegister
                            ? Column(
                                key: const ValueKey('name-field'),
                                children: [
                                  _buildField(
                                    controller: _nameCtrl,
                                    label: 'Full Name',
                                    hint: 'Enter your full name',
                                    icon: Icons.person_outline_rounded,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.name],
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Full name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('no-name-field'),
                              ),
                      ),
                      _buildField(
                        controller: _emailCtrl,
                        label: 'Email Address',
                        hint: 'Enter your email',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email address is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _passCtrl,
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePass,
                        textInputAction: TextInputAction.done,
                        autofillHints: _isRegister
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        suffix: IconButton(
                          onPressed: () {
                            setState(() => _obscurePass = !_obscurePass);
                          },
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _textMuted,
                            size: 21,
                          ),
                        ),
                        onSubmitted: (_) => auth.loading ? null : _submit(),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }

                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildPrimaryButton(auth),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.shield_outlined,
                            size: 15,
                            color: _textMuted,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Secure TELEX company access',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/logos/txhive-icon-primary-512.png',
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _dark,
                  shape: BoxShape.circle,
                  border: Border.all(color: _white, width: 3),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: _white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Image.asset(
          'assets/logos/txhive-logo-primary-letters.png',
          height: 26,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 4),
        const Text(
          'Internal Messaging Workspace',
          style: TextStyle(
            color: _textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _buildModeTab(
            label: 'Log In',
            selected: !_isRegister,
            onTap: () => setState(() => _isRegister = false),
          ),
          _buildModeTab(
            label: 'Sign Up',
            selected: _isRegister,
            onTap: () => setState(() => _isRegister = true),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _primary : _textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(AuthProvider auth) {
    final String label = _isRegister ? 'Create Account' : 'Log In';

    return Opacity(
      opacity: auth.loading ? 0.72 : 1,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_primaryDark, _primary, Color(0xFFD30000)],
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: auth.loading ? null : _submit,
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: auth.loading
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: _white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: _white,
                          size: 19,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    Iterable<String>? autofillHints,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      enableSuggestions: !obscureText,
      autocorrect: !obscureText,
      style: const TextStyle(
        fontSize: 14,
        color: _textDark,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: _textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFFB3B3B3),
          fontSize: 13,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(
            icon,
            color: _primary,
            size: 21,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: _field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE9E9EC),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: _primary,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: _primary,
            width: 1.4,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: _primary,
            width: 1.6,
          ),
        ),
      ),
      validator: validator,
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF250000),
                  Color(0xFFA10000),
                  Color(0xFF171717),
                ],
                stops: [0.0, 0.48, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -90,
          right: -80,
          child: _BlurCircle(
            size: 250,
            color: const Color(0xFFFF4D4D),
            opacity: 0.28,
          ),
        ),
        Positioned(
          left: -110,
          bottom: -110,
          child: _BlurCircle(
            size: 290,
            color: const Color(0xFF000000),
            opacity: 0.35,
          ),
        ),
        Positioned(
          top: 90,
          left: -80,
          child: _BlurCircle(
            size: 190,
            color: const Color(0xFFFFFFFF),
            opacity: 0.08,
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 230,
          child: CustomPaint(
            painter: _BackgroundWavePainter(),
          ),
        ),
      ],
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}

class _BackgroundWavePainter extends CustomPainter {
  const _BackgroundWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final firstPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final secondPaint = Paint()
      ..color = Colors.black.withOpacity(0.16)
      ..style = PaintingStyle.fill;

    final firstPath = Path();
    firstPath.moveTo(0, size.height * 0.50);
    firstPath.cubicTo(
      size.width * 0.22,
      size.height * 0.28,
      size.width * 0.48,
      size.height * 0.72,
      size.width * 0.72,
      size.height * 0.46,
    );
    firstPath.cubicTo(
      size.width * 0.86,
      size.height * 0.30,
      size.width * 0.96,
      size.height * 0.42,
      size.width,
      size.height * 0.34,
    );
    firstPath.lineTo(size.width, size.height);
    firstPath.lineTo(0, size.height);
    firstPath.close();

    final secondPath = Path();
    secondPath.moveTo(0, size.height * 0.70);
    secondPath.cubicTo(
      size.width * 0.18,
      size.height * 0.55,
      size.width * 0.42,
      size.height * 0.92,
      size.width * 0.68,
      size.height * 0.70,
    );
    secondPath.cubicTo(
      size.width * 0.84,
      size.height * 0.56,
      size.width,
      size.height * 0.68,
      size.width,
      size.height * 0.60,
    );
    secondPath.lineTo(size.width, size.height);
    secondPath.lineTo(0, size.height);
    secondPath.close();

    canvas.drawPath(firstPath, firstPaint);
    canvas.drawPath(secondPath, secondPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
