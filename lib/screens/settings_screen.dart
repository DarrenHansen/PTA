import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/business_profile_provider.dart';
import '../models/business_profile.dart';
import '../utils/app_localizations.dart';
import 'business_profile_screen.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';

/// Settings Screen - Pengaturan aplikasi
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                loc.get('settings'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Appearance section
              Text(
                loc.get('appearance'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFE94560)
                      : const Color(0xFF1A1A2E),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildSettingsCard(
                context,
                isDark: isDark,
                children: [
                  // Dark Mode toggle
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      return _SettingsTile(
                        icon: isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        iconColor: isDark
                            ? const Color(0xFFE94560)
                            : const Color(0xFF1A1A2E),
                        title: loc.get('dark_mode'),
                        subtitle: isDark
                            ? loc.get('dark_mode_active')
                            : loc.get('light_mode_active'),
                        trailing: Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (_) => themeProvider.toggleTheme(),
                          activeColor: isDark
                              ? const Color(0xFFE94560)
                              : const Color(0xFF1A1A2E),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  // Language selection
                  Consumer<LocaleProvider>(
                    builder: (context, localeProvider, _) {
                      return _SettingsTile(
                        icon: Icons.language,
                        iconColor: isDark
                            ? const Color(0xFFE94560)
                            : const Color(0xFF1A1A2E),
                        title: loc.get('language'),
                        subtitle: localeProvider.isIndonesian
                            ? 'Bahasa Indonesia'
                            : 'English',
                        trailing: DropdownButton<String>(
                          value: localeProvider.locale.languageCode,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 'id', child: Text('ID')),
                            DropdownMenuItem(value: 'en', child: Text('EN')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              localeProvider.setLocale(Locale(value));
                            }
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Business Profile section
              Text(
                loc.get('business_profile'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFE94560)
                      : const Color(0xFF1A1A2E),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildSettingsCard(
                context,
                isDark: isDark,
                children: [
                  _SettingsTile(
                    icon: Icons.business_outlined,
                    iconColor: isDark
                        ? const Color(0xFFE94560)
                        : const Color(0xFF1A1A2E),
                    title: loc.get('business_profile'),
                    subtitle: loc.get('business_profile_desc'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BusinessProfileScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Features section
              Text(
                loc.get('features'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFE94560)
                      : const Color(0xFF1A1A2E),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildSettingsCard(
                context,
                isDark: isDark,
                children: [
                  _SettingsTile(
                    icon: Icons.picture_as_pdf_outlined,
                    title: loc.get('pdf_export'),
                    subtitle: loc.get('pdf_desc'),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.share_outlined,
                    title: loc.get('share_feature'),
                    subtitle: loc.get('share_desc'),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.search_outlined,
                    title: loc.get('search_filter'),
                    subtitle: loc.get('search_filter_desc'),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: loc.get('notifications'),
                    subtitle:
                        'H-7, H-3, H-1 ${loc.get('notification_reminder')}',
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.label_outline,
                    title: loc.get('status_tracking'),
                    subtitle: loc.get('status_tracking_desc'),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _buildSettingsCard(
                context,
                isDark: isDark,
                children: [
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    iconColor: Colors.redAccent,
                    title: 'Keluar dari akun',
                    subtitle: 'Akun tetap tersimpan di perangkat ini',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await AuthService.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const AuthScreen(hasAccount: true),
                        ),
                        (_) => false,
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F0F5),
        ),
      ),
      child: Column(children: children),
    );
  }
}

/// Settings tile widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFF1A1A2E)).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF8888AA) : const Color(0xFF9999AA),
        ),
      ),
      trailing: trailing,
    );
  }
}
