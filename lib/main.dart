import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'app_localizations.dart';
import 'providers/auth_provider.dart';
import 'screens/commercial_dashboard_screen.dart';
import 'screens/commercial_register_screen.dart';
import 'screens/create_prescription_screen.dart';
import 'screens/login_screen.dart';
import 'screens/news_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/prescriptions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/search_medications_screen.dart';
import 'screens/search_pharmacies_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/upgrade_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/main_shell.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await initializeDateFormatting('fr_FR', null);
  await NotificationService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        Provider(create: (_) => ApiService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAKYMED',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Indispensable pour les sélecteurs de date/heure Material en français
      // (sinon « No MaterialLocalizations found » à l'ouverture du calendrier).
      locale: AppLocalizationConfig.locale,
      supportedLocales: AppLocalizationConfig.supportedLocales,
      localizationsDelegates: AppLocalizationConfig.delegates,
      // Les tailles de police système « très grandes » cassaient la barre de
      // navigation (libellés sur deux lignes) et tronquaient certains boutons :
      // on borne l'agrandissement tout en respectant les préférences raisonnables.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.15,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const MainShell(),
        '/prescriptions': (context) => const OrdonnancesScreen(),
        '/create-prescription': (context) => const CreatePrescriptionScreen(),
        '/search-medications': (context) => const SearchMedicationsScreen(),
        '/search-pharmacies': (context) => const SearchPharmaciesScreen(),
        '/news': (context) => const NewsScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/upgrade': (context) => const UpgradeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/commercial-register': (context) => const CommercialRegisterScreen(),
        '/commercial-dashboard': (context) => const CommercialDashboardScreen(),
      },
    );
  }
}

/// Splash → onboarding (à chaque ouverture) → auth ou application.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  /// Volontairement non persisté : l'onboarding se rejoue à chaque lancement
  /// de l'application (choix produit), il n'est ignoré que pour la session en cours.
  bool _onboardingDone = false;
  bool _pollingStarted = false;

  void _onOnboardingComplete() {
    if (mounted) setState(() => _onboardingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final apiService = Provider.of<ApiService>(context, listen: false);

    Widget child;
    if (!authProvider.isInitialized) {
      child = const SplashScreen();
    } else if (!_onboardingDone) {
      child = OnboardingScreen(onComplete: _onOnboardingComplete);
    } else if (authProvider.isAuthenticated) {
      if (!_pollingStarted) {
        _pollingStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          PushService.startPolling(apiService, authProvider.user!.id);
        });
      }
      child = const MainShell();
    } else {
      if (_pollingStarted) {
        _pollingStarted = false;
        PushService.stopPolling();
      }
      child = const LoginScreen();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      child: child,
    );
  }
}
