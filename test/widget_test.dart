// Test de non-régression « débordements » : chaque écran est rendu sur un
// petit écran (320 dp) avec la police système agrandie. Tout RenderFlex
// overflow ou exception de layout fait échouer le test.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:takymed_mobile/app_localizations.dart';
import 'package:takymed_mobile/providers/auth_provider.dart';
import 'package:takymed_mobile/screens/auth_screen.dart';
import 'package:takymed_mobile/screens/commercial_dashboard_screen.dart';
import 'package:takymed_mobile/screens/commercial_register_screen.dart';
import 'package:takymed_mobile/screens/create_prescription_screen.dart';
import 'package:takymed_mobile/screens/dashboard_screen.dart';
import 'package:takymed_mobile/screens/medication_detail_screen.dart';
import 'package:takymed_mobile/screens/pharmacy_details_screen.dart';
import 'package:takymed_mobile/screens/prescription_detail_screen.dart';
import 'package:takymed_mobile/screens/news_screen.dart';
import 'package:takymed_mobile/screens/notifications_screen.dart';
import 'package:takymed_mobile/screens/onboarding_screen.dart';
import 'package:takymed_mobile/screens/prescriptions_screen.dart';
import 'package:takymed_mobile/screens/profile_screen.dart';
import 'package:takymed_mobile/screens/search_medications_screen.dart';
import 'package:takymed_mobile/screens/search_pharmacies_screen.dart';
import 'package:takymed_mobile/screens/settings_screen.dart';
import 'package:takymed_mobile/screens/upgrade_screen.dart';
import 'package:takymed_mobile/services/api_service.dart';
import 'package:takymed_mobile/services/pharmacy_garde_service.dart';
import 'package:takymed_mobile/theme/app_theme.dart';
import 'package:takymed_mobile/widgets/main_shell.dart';
import 'package:takymed_mobile/widgets/pin_field.dart';
import 'package:takymed_mobile/widgets/primary_button.dart';
import 'package:takymed_mobile/widgets/reminder_notification_config.dart';

/// Gabarits testés : (largeur, hauteur, facteur de police).
const _profiles = <(double, double, double)>[(320, 640, 1.0), (320, 640, 1.3), (360, 780, 1.15)];

Widget _harness(Widget child, double scale) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      Provider(create: (_) => ApiService()),
    ],
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: MaterialApp(
        theme: AppTheme.light,
        locale: AppLocalizationConfig.locale,
        supportedLocales: AppLocalizationConfig.supportedLocales,
        localizationsDelegates: AppLocalizationConfig.delegates,
        home: child,
      ),
    ),
  );
}

Future<void> _renderAll(
  WidgetTester tester,
  String name,
  Widget Function() build, {
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  for (final (w, h, scale) in _profiles) {
    tester.view.physicalSize = Size(w, h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // On capture les erreurs de rendu nous-mêmes pour conserver la ligne
    // « The relevant error-causing widget was » (fichier:ligne du widget fautif).
    final captured = <FlutterErrorDetails>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = captured.add;
    try {
      await tester.pumpWidget(_harness(build(), scale));
      // Laisser passer les animations d'entrée et les Future.delayed sans
      // exiger la stabilité (certaines animations bouclent volontairement).
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (interact != null) {
        await interact(tester);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      }
    } finally {
      FlutterError.onError = previousHandler;
    }
    final summary = captured
        .map((d) {
          final lines = d.toString().split('\n');
          final where = lines
              .where((l) => (l.contains('.dart:') && !l.contains('package:flutter/')) || l.contains('creator:'))
              .take(3)
              .join(' | ');
          return '${d.exceptionAsString()} → $where';
        })
        .toSet()
        .join('\n');
    expect(captured, isEmpty, reason: '$name — ${w.toInt()}x${h.toInt()} @x$scale :\n$summary');

    // Démonter pour libérer timers et contrôleurs avant le gabarit suivant.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Widgets réutilisables', () {
    testWidgets('PinField tient dans une carte étroite', (tester) async {
      await _renderAll(
        tester,
        'PinField',
        () => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: PinField(controller: TextEditingController(text: '123'), autofocus: false),
              ),
            ),
          ),
        ),
      );
    });

    testWidgets('ChannelSelector (WhatsApp, SMS, push, appel) sans débordement', (tester) async {
      await _renderAll(
        tester,
        'ChannelSelector',
        () => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ChannelSelector(channels: const {'whatsapp', 'sms'}, onToggle: (_) {}),
              ),
            ),
          ),
        ),
      );
    });

    testWidgets('PrimaryButton avec libellé long', (tester) async {
      await _renderAll(
        tester,
        'PrimaryButton',
        () => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                PrimaryButton(label: 'Recevoir un nouveau code PIN par SMS maintenant', icon: Icons.sms_rounded, onPressed: () {}),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Localisation…', icon: Icons.my_location_rounded, expanded: false, height: 42, onPressed: () {}),
              ],
            ),
          ),
        ),
      );
    });
  });

  group('Écrans', () {
    testWidgets('Onboarding', (tester) async {
      await _renderAll(tester, 'Onboarding', () => OnboardingScreen(onComplete: () {}));
    });

    testWidgets('Connexion', (tester) async {
      await _renderAll(tester, 'Connexion', () => const AuthScreen(mode: AuthMode.login));
    });

    testWidgets('Création de compte', (tester) async {
      await _renderAll(tester, 'Inscription', () => const AuthScreen(mode: AuthMode.register));
    });

    testWidgets('Inscription commerciale', (tester) async {
      await _renderAll(tester, 'CommercialRegister', () => const CommercialRegisterScreen());
    });

    testWidgets('Recherche de médicaments', (tester) async {
      await _renderAll(tester, 'SearchMedications', () => const SearchMedicationsScreen());
    });

    testWidgets('Pharmacies', (tester) async {
      await _renderAll(tester, 'SearchPharmacies', () => const SearchPharmaciesScreen());
    });

    testWidgets('Pharmacies — onglet « Par ville » affiche les résultats', (tester) async {
      // Sans réseau dans les tests : on alimente le cache du service.
      PharmacyGardeService.seedCache(
        cities: const [
          CityEntry(city: 'Yaoundé', region: 'Centre'),
          CityEntry(city: 'Bafoussam', region: 'Ouest'),
        ],
        byCity: {
          'Bafoussam': PharmacySearchResult.fromJson({
            'city': 'Bafoussam',
            'normalizedCity': 'bafoussam',
            'status': 'ok',
            'message': '2 pharmacie(s) trouvée(s) à Bafoussam.',
            'count': 2,
            'pharmacies': [
              {
                'osmId': 'way/1',
                'name': 'Pharmacie Ange Gabriel',
                'city': 'Bafoussam',
                'address': 'Boulevard du Renouveau, Bafoussam II',
                'phones': ['+237 699 00 00 00'],
                'location': {'lat': 5.48, 'lng': 10.41},
                'sourceUrl': '',
              },
              {
                'osmId': 'way/2',
                'name': 'Pharmacie du Marché — nom volontairement très long pour tester la troncature',
                'city': 'Bafoussam',
                'address': 'Marché A',
                'phones': [],
                'location': {'lat': 5.47, 'lng': 10.42},
                'sourceUrl': '',
              },
            ],
            'fetchedAt': '',
            'cache': 'hit',
          }),
        },
      );
      addTearDown(PharmacyGardeService.clearCache);

      await _renderAll(
        tester,
        'SearchPharmacies/ville',
        () => const SearchPharmaciesScreen(),
        interact: (tester) async {
          await tester.tap(find.text('Par ville'));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          await tester.tap(find.widgetWithIcon(ElevatedButton, Icons.search_rounded));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(find.textContaining('Pharmacie Ange Gabriel'), findsOneWidget);
          expect(find.textContaining('2 pharmacie(s) trouvée(s)'), findsOneWidget);
        },
      );
    });

    testWidgets('Nouvelle ordonnance', (tester) async {
      await _renderAll(tester, 'CreatePrescription', () => const CreatePrescriptionScreen());
    });

    testWidgets('Ajout de médicament — durée par défaut 1 jour et calendrier « Début de prise » utilisable', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(
          Scaffold(body: AddMedicationForm(onAdd: (_) {})),
          1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Durée par défaut : 1 jour (et non 7).
      final durationField = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == '1');
      expect(find.text('7'), findsNothing);
      expect(durationField, findsWidgets);

      // Le calendrier s'ouvre sans erreur de localisation.
      final pickDate = find.ancestor(of: find.byIcon(Icons.event_rounded), matching: find.byType(InkWell)).first;
      await tester.ensureVisible(pickDate);
      await tester.pumpAndSettle();
      await tester.tap(pickDate, warnIfMissed: true);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('Début de prise de ce médicament'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Paramètres', (tester) async {
      await _renderAll(tester, 'Settings', () => const SettingsScreen());
    });

    testWidgets('Offres', (tester) async {
      await _renderAll(tester, 'Upgrade', () => const UpgradeScreen());
    });
  });

  group('Écrans connectés', () {
    const storedUser = {
      'id': 42,
      'name': 'Marie-Chantal Ngo Bakang Épouse Mbappé',
      'phone': '+237657635644',
      'type': 'standard',
      'country': 'CM',
      'timezone': 'Africa/Douala',
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({'user': jsonEncode(storedUser)});
    });

    testWidgets('Coque principale (onglets + barre de navigation)', (tester) async {
      await _renderAll(tester, 'MainShell', () => const MainShell());
    });

    testWidgets('Tableau de bord', (tester) async {
      await _renderAll(tester, 'Dashboard', () => const DashboardScreen());
    });

    testWidgets('Ordonnances', (tester) async {
      await _renderAll(tester, 'Ordonnances', () => const OrdonnancesScreen());
    });

    testWidgets('Profil', (tester) async {
      await _renderAll(tester, 'Profile', () => const ProfileScreen());
    });

    testWidgets('Notifications', (tester) async {
      await _renderAll(tester, 'Notifications', () => const NotificationsScreen());
    });

    testWidgets('Nouveautés', (tester) async {
      await _renderAll(tester, 'News', () => const NewsScreen());
    });

    testWidgets('Détail d\'une ordonnance (titre et patient longs)', (tester) async {
      await _renderAll(
        tester,
        'PrescriptionDetail',
        () => const PrescriptionDetailScreen(
          ordonnance: {
            'id': 7,
            'titre': 'Traitement antihypertenseur et antidiabétique de longue durée',
            'nom_patient': 'Marie-Chantal Ngo Bakang Épouse Mbappé',
            'categorie_age': 'adulte',
            'poids_patient': 72,
            'est_active': 1,
            'date_ordonnance': '2026-09-01T08:00:00.000Z',
            'medicaments': [
              {'nom_medicament': 'Amlodipine bésilate 10 mg comprimé pelliculé sécable', 'dose': '1 comprimé', 'frequence': 1, 'duree': 30},
              {'nom_medicament': 'Metformine', 'dose': '850 mg', 'frequence': 2, 'duree': 30},
            ],
            'rappels': ['whatsapp', 'sms'],
          },
        ),
      );
    });

    testWidgets('Détail d\'une pharmacie', (tester) async {
      await _renderAll(
        tester,
        'PharmacyDetails',
        () => PharmacyDetailsScreen(
          pharmacy: PharmacyGarde(
            osmId: 'node/1',
            name: 'Pharmacie de la Cathédrale Notre-Dame des Victoires',
            city: 'Yaoundé',
            address: 'Avenue Jean-Paul II, quartier Centre administratif, en face de la cathédrale',
            phones: const ['+237 699 00 00 00', '+237 222 22 22 22'],
            lat: 3.866,
            lng: 11.516,
            sourceUrl: 'https://www.openstreetmap.org/node/1',
            isOnDuty: true,
            distanceKm: 12.345,
          ),
        ),
      );
    });

    testWidgets('Détail d\'un médicament', (tester) async {
      await _renderAll(
        tester,
        'MedicationDetail',
        () => const MedicationDetailScreen(
          heroTag: 'med-1',
          medication: {
            'id': 1,
            'name': 'Amoxicilline / acide clavulanique 875 mg / 125 mg comprimé',
            'type': 'Antibiotique',
            'price': 12500,
            'isNew': true,
            'description':
                'Association d\'une pénicilline et d\'un inhibiteur de bêta-lactamase indiquée dans les infections bactériennes.',
            'precautions': 'Ne pas utiliser en cas d\'allergie aux pénicillines. Respecter la posologie et la durée prescrites.',
          },
          interactions: [
            {
              'medication1': 'Amoxicilline',
              'medication2': 'Méthotrexate',
              'severity': 'high',
              'description': 'Augmentation de la toxicité du méthotrexate.',
            },
          ],
        ),
      );
    });

    testWidgets('Espace commercial', (tester) async {
      SharedPreferences.setMockInitialValues({
        'user': jsonEncode({...storedUser, 'type': 'commercial'}),
      });
      await _renderAll(tester, 'CommercialDashboard', () => const CommercialDashboardScreen());
    });
  });
}
