import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Configuration de localisation partagée entre l'application et les tests.
///
/// Les sélecteurs de date/heure Material exigent `MaterialLocalizations` pour
/// la locale demandée ; sans ces délégués, `showDatePicker(locale: fr_FR)`
/// lève « No MaterialLocalizations found ».
abstract final class AppLocalizationConfig {
  static const Locale locale = Locale('fr', 'FR');

  static const List<Locale> supportedLocales = [Locale('fr', 'FR'), Locale('en', 'US')];

  static const List<LocalizationsDelegate<dynamic>> delegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
