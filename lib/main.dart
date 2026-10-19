import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'services/firebase_config.dart';
import 'screens/firebase_setup_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/theme_provider.dart';
import 'providers/invoice_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/product_provider.dart';
import 'providers/business_profile_provider.dart';
import 'providers/locale_provider.dart';

import 'utils/app_localizations.dart';
import 'utils/notification_helper.dart';

import 'screens/welcome_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/auth_screen.dart';
import 'services/auth_service.dart';

/// Check first app launch
Future<bool> isFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();

  final hasOpened = prefs.getBool('has_opened_app') ?? false;

  if (!hasOpened) {
    await prefs.setBool('has_opened_app', true);
    return true;
  }

  return false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!FirebaseConfig.isConfigured) {
    runApp(const FirebaseSetupScreen());
    return;
  }
  await Firebase.initializeApp(options: FirebaseConfig.currentPlatform);

  /// Check onboarding state
  final firstLaunch = await isFirstLaunch();
  final hasAccount = await AuthService.hasAccount;
  final signedIn = await AuthService.isSignedIn;

  /// Initialize notifications
  if (!kIsWeb) await NotificationHelper.initialize();
  if (!kIsWeb) await NotificationHelper.requestPermissions();

  /// Transparent status bar
  if (!kIsWeb)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

  /// Lock portrait
  if (!kIsWeb)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => BusinessProfileProvider()),
      ],
      child: MyApp(
          firstLaunch: firstLaunch, hasAccount: hasAccount, signedIn: signedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool firstLaunch;
  final bool hasAccount;
  final bool signedIn;

  const MyApp({
    super.key,
    this.firstLaunch = false,
    this.hasAccount = false,
    this.signedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp(
      title: 'Fasnote',
      debugShowCheckedModeBanner: false,

      /// Theme
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      /// Localization
      locale: localeProvider.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('id'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      /// First launch logic
      home: !signedIn
          ? (firstLaunch
              ? const WelcomeScreen()
              : AuthScreen(hasAccount: hasAccount))
          : const MainNavigationScreen(),

      /// Prevent system font scaling
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
