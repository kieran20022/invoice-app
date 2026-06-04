import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo / Brand
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text(
                'InvoiceApp',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create professional invoices in minutes',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),

              const Spacer(flex: 2),

              // Feature bullets
              ...[
                ('receipt_long', 'Create & manage invoices'),
                ('picture_as_pdf', 'Download as PDF'),
                ('email', 'Send directly to clients'),
              ].map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _iconFromString(f.$1),
                          color: AppTheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        f.$2,
                        style: const TextStyle(
                            fontSize: 15, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              if (auth.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Google Sign In button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.textPrimary,
                  ),
                  onPressed: auth.isLoading ? null : () => context.read<AuthProvider>().signInWithGoogle(),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://www.google.com/favicon.ico',
                              width: 20,
                              height: 20,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.g_mobiledata, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFromString(String name) {
    switch (name) {
      case 'receipt_long':
        return Icons.receipt_long;
      case 'picture_as_pdf':
        return Icons.picture_as_pdf;
      case 'email':
        return Icons.email;
      default:
        return Icons.check;
    }
  }
}
