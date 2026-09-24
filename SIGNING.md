# Signature Android

## Ce que Play Console exige

Play rejette un AAB dont la signature ne correspond pas au **certificat d'upload
enregistré pour l'app** (`Play Console → Setup → App signing`). Au dernier upload,
l'empreinte exigée était :

```
08:DA:39:55:90:CE:8E:EB:7E:86:72:91:AB:42:2F:73:A8:E7:AB:6C
```

Le keystore qui produit cette empreinte n'est **pas** sur la machine de dev actuelle :
il est probablement dans le `~/.android/debug.keystore` d'un autre poste (l'ancien
`build.gradle.kts` signait le `release` avec la clé debug, donc tout AAB uploadé avant
ceci portait l'empreinte du debug keystore de la machine qui l'a buildé).

Deux issues possibles :

- **Retrouver cet ancien keystore** : sur le poste suspect, `keytool -list -v
  -keystore ~/.android/debug.keystore -storepass android | grep -iE 'sha.?1'`. Si ça
  sort `08:DA:39:…`, copier le fichier vers `android/` et pointer `key.properties`
  dessus → l'upload passe sans formalité.
- **Réinitialiser la clé d'upload** dans Play Console avec le certificat de
  `android/takymed-upload.jks` (empreinte `F7:03:D1:C6:C3:12:AF:80:1F:95:18:1B:1A:EC:2E:61:24:92:BB:08`).
  Après validation, c'est cette clé propre qui est attendue à l'upload.

Dans les deux cas, une fois la clé retenue, mettre à jour **la variable de dépôt
`RELEASE_SHA1`** (et les secrets si le keystore change) : la CI compare l'empreinte du
keystore reconstitué ET celle de l'APK produit à cette valeur, et rouge sinon.

Package : `com.takymed.takymed_mobile`

Pour une restriction de clé API Google Cloud (Maps SDK, Firebase Auth, Google Sign-In),
déclarer l'empreinte **de la clé qui signe les builds distribuées** (celle du Store, via
Play App Signing) **et** celle des builds locales/CI sous le même package name.

## Le matériel de signature n'est jamais dans git

`android/.gitignore` exclut déjà `key.properties` et `*.jks`. Trois fichiers forment la
signature, et ils doivent être **identiques octet pour octet** sur chaque machine :

- `android/takymed-upload.jks` — le keystore
- `android/key.properties` — les mots de passe et l'alias
- `build.gradle.kts` — lit `key.properties` via `rootProject.file(...)`

`build.gradle.kts` ne tombe plus jamais sur une clé par défaut : sans `key.properties`
valides, un `--release` échoue au lieu de resigner silencieusement avec la clé debug.

## Installer la signature sur une nouvelle machine (macOS ou Linux)

Récupérer les deux fichiers depuis la machine qui héberge la clé retenue :

```bash
# depuis le poste source (adaptez le chemin du projet)
scp <hote>:TAKYMED-M/android/takymed-upload.jks android/
scp <hote>:TAKYMED-M/android/key.properties      android/
chmod 600 android/takymed-upload.jks android/key.properties
```

Vérifier que l'empreinte est bien la bonne (la sortie dépend de la locale, d'où le filtre) :

```bash
keytool -list -v -keystore android/takymed-upload.jks \
  -storepass "$(sed -n 's/^storePassword=//p' android/key.properties)" -alias takymed-upload \
  | grep -iE 'sha.?1'
# attendu : F7:03:D1:C6:C3:12:AF:80:1F:95:18:1B:1A:EC:2E:61:24:92:BB:08
```

## Secrets et variables GitHub Actions

Le workflow `android-release.yml` reconstruit le keystore depuis les secrets :

| Secret | Contenu |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 android/takymed-upload.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` de `key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` de `key.properties` |
| `ANDROID_KEY_ALIAS` | `takymed-upload` |

| Variable | Contenu |
|---|---|
| `RELEASE_SHA1` | empreinte SHA-1 de la clé d'upload retenue, ex. `F7:03:D1:…` |

Pose des secrets :

```bash
base64 -w0 android/takymed-upload.jks | gh secret set ANDROID_KEYSTORE_BASE64 --repo TE-SEA-Incubator/TAKYMED-M
gh secret set ANDROID_KEYSTORE_PASSWORD --repo TE-SEA-Incubator/TAKYMED-M < <(sed -n 's/^storePassword=//p' android/key.properties)
gh secret set ANDROID_KEY_PASSWORD     --repo TE-SEA-Incubator/TAKYMED-M < <(sed -n 's/^keyPassword=//p' android/key.properties)
gh secret set ANDROID_KEY_ALIAS        --repo TE-SEA-Incubator/TAKYMED-M <<< takymed-upload
```

Le workflow contrôle l'empreinte du keystore reconstitué **avant** de builder, puis
vérifie celle de l'APK produit : si un secret pointe vers un autre keystore, la CI rouge
au lieu de livrer une build resignée.

## Régénérer la clé d'upload

À éviter : Play refuse tout upload suivant si la clé d'upload change, il faut d'abord
faire *Play Console → Setup → App signing → Reset upload key*. La clé de signature Play,
elle, est irrécupérable si perdue — c'est Google qui la détient.
