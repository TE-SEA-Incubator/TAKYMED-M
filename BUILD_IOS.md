# TAKYMED mobile — build iOS sur Mac

Prérequis : macOS récent, Xcode (avec les outils en ligne de commande), CocoaPods
(`sudo gem install cocoapods`), Flutter stable (`flutter doctor` sans erreur iOS).

```bash
cd mobile
flutter clean
flutter pub get
cd ios && pod install && cd ..

# Vérification rapide
flutter analyze
flutter test

# Build sans signature (vérifie que tout compile)
flutter build ios --release --no-codesign
```

## Signature et publication

1. Ouvrir `ios/Runner.xcworkspace` dans Xcode.
2. Cible **Runner** → onglet *Signing & Capabilities* : choisir votre équipe Apple
   Developer et un Bundle Identifier (ex. `com.takymed.mobile`).
3. Capabilities déjà déclarées dans `Info.plist` : localisation en cours d'utilisation,
   notifications, modes d'arrière-plan (fetch, remote-notification), schémas
   `tel`, `https`, `whatsapp`, `maps` pour les boutons Appeler / WhatsApp / Itinéraire.
   Ajouter la capability **Push Notifications** dans Xcode si vous activez les notifications distantes.
4. Générer l'archive : `flutter build ipa --release` (ou Product → Archive dans Xcode),
   puis envoyer sur App Store Connect via Xcode Organizer ou Transporter.

## Notes

- La version affichée est celle de `pubspec.yaml` (`version: x.y.z+build`). Bumper avec
  `node ../scripts/bump-mobile-version.mjs` depuis la racine du repo avant chaque livraison.
- L'URL de l'API est dans `lib/services/api_service.dart` (`baseUrl`).
- Cible iOS minimale : 13.0 (`IPHONEOS_DEPLOYMENT_TARGET`). Si CocoaPods réclame plus, passer
  la plateforme à 13.0 dans `ios/Podfile` (`platform :ios, '13.0'`).
