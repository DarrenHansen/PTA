import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_localizations.dart';
import 'main_navigation_screen.dart';
import 'auth_screen.dart';

/// Welcome Screen - Splash / Onboarding screen
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFE94560)
                              : const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.receipt_long_outlined,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        loc.get('app_title'),
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        loc.get('welcome_subtitle'),
                        style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? const Color(0xFF8888AA)
                                : const Color(0xFF888899),
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 2),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFFF5F5FA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 20,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 80,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF16162A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2A2A4A)
                                    : const Color(0xFFEEEEF0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1A3A2A)
                                      : const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.check_circle,
                                    size: 18,
                                    color: isDark
                                        ? const Color(0xFF66BB6A)
                                        : const Color(0xFF2E7D32)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                        width: 100,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF2A2A4A)
                                                : const Color(0xFFEEEEF0),
                                            borderRadius:
                                                BorderRadius.circular(4))),
                                    const SizedBox(height: 6),
                                    Container(
                                        width: 140,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF2A2A4A)
                                                : const Color(0xFFEEEEF0),
                                            borderRadius:
                                                BorderRadius.circular(4))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 40,
                        right: 40,
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF16162A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2A2A4A)
                                    : const Color(0xFFEEEEF0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF3A1A1A)
                                      : const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.warning,
                                    size: 18,
                                    color: isDark
                                        ? const Color(0xFFEF5350)
                                        : const Color(0xFFC62828)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                        width: 80,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF2A2A4A)
                                                : const Color(0xFFEEEEF0),
                                            borderRadius:
                                                BorderRadius.circular(4))),
                                    const SizedBox(height: 6),
                                    Container(
                                        width: 120,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF2A2A4A)
                                                : const Color(0xFFEEEEF0),
                                            borderRadius:
                                                BorderRadius.circular(4))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFeature(context,
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'PDF Export',
                        isDark: isDark),
                    _buildFeature(context,
                        icon: Icons.share_outlined,
                        label: 'Share',
                        isDark: isDark),
                    _buildFeature(context,
                        icon: Icons.dark_mode_outlined,
                        label: 'Dark Mode',
                        isDark: isDark),
                    _buildFeature(context,
                        icon: Icons.search_outlined,
                        label: 'Search',
                        isDark: isDark),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fadeAnimation,
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFFE94560)
                          : const Color(0xFF1A1A2E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) =>
                              const AuthScreen(hasAccount: false),
                          transitionDuration: const Duration(milliseconds: 500),
                          transitionsBuilder: (_, animation, __, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                        begin: const Offset(0.05, 0),
                                        end: Offset.zero)
                                    .animate(CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic)),
                                child: child,
                              ),
                            );
                          },
                        ),
                      );
                    },
                    child: Text(
                      loc.get('get_started'),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(BuildContext context,
      {required IconData icon, required String label, required bool isDark}) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F0F5),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon,
              size: 20,
              color:
                  isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E)),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? const Color(0xFF8888AA)
                    : const Color(0xFF888899))),
      ],
    );
  }
}
