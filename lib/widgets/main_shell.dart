import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/commercial_dashboard_screen.dart';
import '../screens/commercial_register_screen.dart';
import '../screens/create_prescription_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/news_screen.dart';
import '../screens/prescriptions_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_medications_screen.dart';
import '../screens/search_pharmacies_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'page_transitions.dart';

/// Onglets de la coquille principale.
enum ShellTab { home, prescriptions, medications, pharmacies, profile }

/// Coquille principale : barre de navigation 5 onglets + bouton d'action contextuel.
class MainShell extends StatefulWidget {
  final ShellTab initialTab;
  const MainShell({super.key, this.initialTab = ShellTab.home});

  /// Permet à un écran enfant de changer d'onglet (ex. "Voir mes ordonnances").
  static MainShellState? of(BuildContext context) => context.findAncestorStateOfType<MainShellState>();

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.index;
  }

  void selectTab(ShellTab tab) {
    if (_index == tab.index) return;
    setState(() => _index = tab.index);
  }

  void _onDestination(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isCommercial = auth.user?.type == 'commercial';

    final pages = <Widget>[
      isCommercial ? const CommercialDashboardScreen(embedded: true) : const DashboardScreen(embedded: true),
      isCommercial ? const NewsScreen(embedded: true) : const OrdonnancesScreen(embedded: true),
      const SearchMedicationsScreen(embedded: true),
      const SearchPharmaciesScreen(embedded: true),
      const ProfileScreen(embedded: true),
    ];

    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded),
        label: isCommercial ? 'Espace' : 'Accueil',
      ),
      isCommercial
          ? const NavigationDestination(
              icon: Icon(Icons.newspaper_outlined),
              selectedIcon: Icon(Icons.newspaper_rounded),
              label: 'Nouveautés',
            )
          : const NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description_rounded),
              label: 'Ordonnances',
            ),
      const NavigationDestination(
        icon: Icon(Icons.medication_outlined),
        selectedIcon: Icon(Icons.medication_rounded),
        label: 'Médicaments',
      ),
      const NavigationDestination(
        icon: Icon(Icons.local_pharmacy_outlined),
        selectedIcon: Icon(Icons.local_pharmacy_rounded),
        label: 'Pharmacies',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profil',
      ),
    ];

    final showFab = isCommercial ? _index == 0 : (_index == 0 || _index == 1);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: AnimatedScale(
        duration: AppDurations.normal,
        curve: Curves.easeOutBack,
        scale: showFab ? 1 : 0,
        child: AnimatedOpacity(
          duration: AppDurations.fast,
          opacity: showFab ? 1 : 0,
          child: _ShellFab(
            label: isCommercial ? 'Nouveau client' : 'Ordonnance',
            icon: isCommercial ? Icons.person_add_alt_1_rounded : Icons.add_rounded,
            onPressed: () => pushSlide(
              context,
              isCommercial ? const CommercialRegisterScreen() : const CreatePrescriptionScreen(),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: AppColors.foreground.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        // Cinq destinations sur un écran étroit : on fige l'échelle du texte et on
        // resserre légèrement la police pour que « Ordonnances » / « Médicaments »
        // tiennent toujours sur une seule ligne.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.0,
          child: NavigationBarTheme(
            data: NavigationBarTheme.of(context).copyWith(
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  letterSpacing: -0.15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.mutedForeground,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onDestination,
              destinations: destinations,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ShellFab({required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: AppRadius.rLg,
        boxShadow: AppShadows.colored(AppColors.primary, alpha: 0.32),
      ),
      child: FloatingActionButton.extended(
        heroTag: 'shell-fab',
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Icon(icon, size: 22),
        label: Text(label),
      ),
    );
  }
}
