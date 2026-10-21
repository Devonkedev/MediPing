import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/firebase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _fs = FirebaseService();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _loading = false;

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  // Platform helpers
  bool get _isIOS => !kIsWeb && Platform.isIOS;
  double get _hPadding => _isIOS ? 24 : 20;
  double get _fieldHeight => _isIOS ? 56 : 60;
  double get _buttonHeight => _isIOS ? 50 : 54;
  double get _cardRadius => _isIOS ? 32 : 28;
  double get _topHeroPadding => _isIOS ? 56 : 48;

  // Brand colors
  static const brandBlue = Color(0xFF1E88E5);
  static const brandGreen = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  // =========================
  // 🔐 EMAIL LOGIN
  // =========================
  Future<void> _login() async {
    if (_loading) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password are required');
      return;
    }

    setState(() => _loading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Login failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // 🆕 SIGN UP
  // =========================
  Future<void> _signup() async {
    if (_loading) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password are required');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _loading = true);

    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Sign-up failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // 🔑 FORGOT PASSWORD
  // =========================
  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email first');
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Failed to send reset email');
    }
  }

  // =========================
  // 🔐 GOOGLE LOGIN
  // =========================
  Future<void> _loginWithGoogle() async {
    if (_loading) return;

    setState(() => _loading = true);
    try {
      await _fs.signInWithGoogle();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (_) {
      _showError('Google sign-in failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // 🍎 APPLE LOGIN (iOS only)
  // =========================
  Future<void> _loginWithApple() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await _fs.signInWithApple();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString().toLowerCase();

      // User cancelled — don't show an error
      if (errStr.contains('canceled') ||
          errStr.contains('cancelled') ||
          errStr.contains('1001')) {
        return;
      }

      // iOS Simulator limitation — Apple Sign-In needs iCloud signed in
      if (errStr.contains('mcpasscodemanager') ||
          errStr.contains('passcode set check is not supported') ||
          errStr.contains('not supported on this device')) {
        _showError(
          'Sign In with Apple is not available on the Simulator. '
          'Please test on a real device.',
        );
        return;
      }

      _showError('Apple sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Opacity(
              opacity: _fade.value,
              child: Transform.translate(
                offset: Offset(0, _slide.value),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              // HEADER
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.only(
                                  top: _topHeroPadding,
                                  bottom: _isIOS ? 44 : 40,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [brandBlue, brandGreen],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(40),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.92),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                            Colors.black.withOpacity(0.15),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Image.asset(
                                          'assets/images/mediping_logo.png',
                                          height: 56,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'MediPing',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Smart health. Instantly connected.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // AUTH CARD
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: _hPadding),
                                child: Container(
                                  padding: EdgeInsets.fromLTRB(
                                    _hPadding,
                                    24,
                                    _hPadding,
                                    _isIOS ? 28 : 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(_cardRadius),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(
                                            _isIOS ? 0.05 : 0.07),
                                        blurRadius: _isIOS ? 30 : 24,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Sign in',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      SizedBox(
                                        height: _fieldHeight,
                                        child: TextField(
                                          controller: _emailCtrl,
                                          decoration:
                                          const InputDecoration(
                                            labelText: 'Email',
                                            prefixIcon: Icon(
                                                Icons.email_outlined),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      SizedBox(
                                        height: _fieldHeight,
                                        child: TextField(
                                          controller: _passwordCtrl,
                                          obscureText: true,
                                          decoration:
                                          const InputDecoration(
                                            labelText: 'Password',
                                            prefixIcon: Icon(
                                                Icons.lock_outline),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _forgotPassword,
                                          child: const Text(
                                              'Forgot Password?'),
                                        ),
                                      ),

                                      const SizedBox(height: 20),

                                      SizedBox(
                                        width: double.infinity,
                                        height: _buttonHeight,
                                        child: FilledButton(
                                          onPressed:
                                          _loading ? null : _login,
                                          style:
                                          FilledButton.styleFrom(
                                            backgroundColor:
                                            brandBlue,
                                            shape:
                                            RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(
                                                  16),
                                            ),
                                          ),
                                          child: _loading
                                              ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child:
                                            CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                              : const Text('Sign In'),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      TextButton(
                                        onPressed:
                                        _loading ? null : _signup,
                                        child: const Text(
                                            'Create new account'),
                                      ),

                                      const SizedBox(height: 20),

                                      const Row(
                                        children: [
                                          Expanded(child: Divider()),
                                          Padding(
                                            padding:
                                            EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text('OR'),
                                          ),
                                          Expanded(child: Divider()),
                                        ],
                                      ),

                                      const SizedBox(height: 20),

                                      SizedBox(
                                        width: double.infinity,
                                        height: _buttonHeight,
                                        child: OutlinedButton.icon(
                                          icon: const Icon(
                                              Icons.g_mobiledata),
                                          label: const Text(
                                              'Continue with Google'),
                                          style:
                                          OutlinedButton.styleFrom(
                                            foregroundColor:
                                            brandGreen,
                                            shape:
                                            RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(
                                                  16),
                                            ),
                                          ),
                                          onPressed: _loading
                                              ? null
                                              : _loginWithGoogle,
                                        ),
                                      ),

                                      // ── Apple Sign-In (iOS only) ──
                                      if (_isIOS) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          height: _buttonHeight,
                                          child: SignInWithAppleButton(
                                            onPressed: _loading
                                                ? () {}
                                                : _loginWithApple,
                                            style: SignInWithAppleButtonStyle.black,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(
                                height:
                                MediaQuery.of(context).padding.bottom +
                                    16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
