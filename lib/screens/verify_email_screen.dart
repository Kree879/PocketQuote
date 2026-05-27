import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _auth = AuthService();
  Timer? _pollingTimer;
  Timer? _cooldownTimer;
  
  bool _isResending = false;
  int _cooldownSeconds = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    // Start polling to check if email has been verified
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        // The auth_wrapper is listening to userChanges(), so as soon as 
        // user.reload() is called, it should pick up the verified state 
        // and navigate away automatically.
      }
    });

    // Check if the user was just created in the last 60 seconds
    final user = FirebaseAuth.instance.currentUser;
    final creationTime = user?.metadata.creationTime;
    final justCreated = creationTime != null &&
        DateTime.now().toUtc().difference(creationTime).inSeconds.abs() < 60;

    if (justCreated) {
      _startCooldown();
    } else {
      _canResend = true;
      _cooldownSeconds = 0;
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _canResend = false;
      _cooldownSeconds = 60;
    });
    
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_cooldownSeconds > 0) {
          _cooldownSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleResendEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isResending = true);
    try {
      await _auth.resendVerificationEmail(user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent!'),
            backgroundColor: Colors.green,
          ),
        );
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend: ${e.toString().split('] ').last}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _handleSignOut() async {
    // Cancel timers immediately
    _pollingTimer?.cancel();
    _cooldownTimer?.cancel();
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleSignOut,
            tooltip: 'Cancel & Log Out',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mark_email_unread_rounded,
                    size: 80,
                    color: AppTheme.accentColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Check your inbox',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  GlassContainer(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'We\'ve sent a verification link to your email address.',
                          style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Please click the link to activate your account. This page will automatically update once you\'re verified.',
                          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: (_canResend && !_isResending) ? _handleResendEmail : null,
                          icon: _isResending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _canResend ? 'Resend Verification Email' : 'Resend in ${_cooldownSeconds}s',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.accentColor,
                            disabledBackgroundColor: Colors.white24,
                            disabledForegroundColor: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _handleSignOut,
                          child: const Text(
                            'Cancel & Log Out',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
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
}
