# Sourdough

SwiftUI-App fürs iPhone, gebaut mit Xcode 27.

Sourdough ist ein **Rezeptrechner für Brot mit Sauerteig**: Bäckerprozente,
Hydration, Anteil des Anstellguts und das Skalieren eines Rezepts auf eine
gewünschte Teigmenge. Die App rechnet; gebacken wird in der eigenen Küche.
Zeitpläne, Starter-Pflege und Backtagebuch gehören nicht zum Umfang.

Der Code ist zweierlei. `Sourdough/` ist die App: Oberfläche und
Speicherung. `SourdoughKit/` ist ein Swift Package mit der **Rechenlogik**,
ohne Xcode-Projekt und ohne Simulator prüfbar.

Stand 2026-11-08: Startanimation (Platzhalter), Startbildschirm mit
Platzhalter-Foto und zwei Optionen (Teig berechnen, Backutensilien),
Utensilien-Wizard mit Speicherung, Hydrationsrechner. Alle drei
Teststockwerke laufen, Abdeckung 100 % (`tools/coverage.sh`). Weitere
Startoptionen sind noch zu planen.

## Aufbau

```
Sourdough.xcodeproj    drei Targets, „Sourdough“, „SourdoughTests“ und
                       „SourdoughUITests“, dazu ein geteiltes Schema
                       „Sourdough“
SourdoughKit/          Swift Package: die Rechenlogik samt Tests
  Sources/SourdoughKit   `Dough` (Hydration mit Anstellgut), `Equipment`
                         (Backutensilien) — Werttypen und reine Funktionen
  Tests/SourdoughKitTests
Sourdough/             Quellcode der App
  SourdoughApp.swift   @main, WindowGroup
  ContentView.swift    Wurzel: Splash über dem Startbildschirm
  SplashView.swift     Startanimation (Platzhalter)
  StartView.swift      Startbildschirm: Foto-Platzhalter und Optionen
  CalculatorView.swift, DoughViewModel.swift   Hydrationsrechner
  EquipmentOverviewView.swift   gespeicherte Utensilien, „Einrichten/Ändern“
  EquipmentWizardView.swift, EquipmentWizardModel.swift   Wizard mit Entwurf
  EquipmentStore.swift Speicherung (UserDefaults, JSON, Schlüssel `equipment.v1`)
  EquipmentText.swift  deutsche Beschreibung der Utensilien
  LaunchOptions.swift  Startparameter für Tests
  Assets.xcassets/
SourdoughTests/        App-Tests (im Simulator, mit der App als Host):
                       Speicherung, View-Modelle, Formatierung
SourdoughUITests/      Oberflächentests: jeder Bildschirm, jede Bedienung
tools/                 Prüfskripte (tests.sh, apptests.sh, uitests.sh,
                       coverage.sh) und simulator.sh (Bezugsgerät)
```

**Logik gehört ins Package.** Alles, was rechnet, liegt in `SourdoughKit/`
und nicht zwischen den Views. Nur dann laufen die Logiktests ohne Host-App
in Sekunden statt Minuten. Die App-Schicht formt Eingaben in Werttypen des
Package um und zeigt Ergebnisse an.

`Sourdough/`, `SourdoughTests/` und `SourdoughUITests/` sind
**synchronisierte Gruppen** (`PBXFileSystemSynchronizedRootGroup`). Neue
Dateien darin landen ohne Eingriff in `project.pbxproj` im jeweiligen
Target. Der Quellordner heißt wie das Target; ein Ordner `MyApp/` aus der
Vorlage wird beim Anlegen umbenannt, nicht stehen gelassen.

## Bauen

```bash
xcodebuild -project Sourdough.xcodeproj -scheme Sourdough -destination 'generic/platform=iOS Simulator' build
```

### Auf das echte iPhone

Signierung ist automatisch eingerichtet; das Profil gilt jeweils rund eine
Woche und muss danach neu erzeugt werden.

```bash
xcodebuild -project Sourdough.xcodeproj -scheme Sourdough -configuration Release -destination 'platform=iOS,id=<Geräte-UDID>' -allowProvisioningUpdates build
```

```bash
xcrun devicectl device install app --device <Geräte-UDID> <Pfad>/Sourdough.app
```

Fürs Gerät `-configuration Release` bauen; der Pfad zum gebauten
`Sourdough.app` endet dann auf `Release-iphoneos/`. `xcrun devicectl list
devices` zeigt gekoppelte Geräte.

### Wenn xcodebuild Xcode nicht findet

Zeigt `xcode-select` auf die Command Line Tools, bricht jeder nackte
`xcodebuild`-Aufruf ab:

```
tool 'xcodebuild' requires Xcode, but active developer directory
'/Library/Developer/CommandLineTools' is a command line tools instance
```

Statt die Einstellung systemweit zu ändern, dem Befehl eine Variable
voranstellen:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild ...
```

Die dauerhafte Lösung wäre `sudo xcode-select -s /Applications/Xcode.app`.
Sie braucht ein Passwort und ist damit Sache des Nutzers, nicht eines Agents.

## Tests

**Vollständige Testabdeckung ist Pflicht, gemessen und nicht geschätzt.**
Keine Änderung am Code ohne die Tests, die sie abdecken; eine Änderung, nach
der die Abdeckung unter 100 % liegt, ist nicht fertig.

### Wann welcher Lauf

- **Laufend** bei jeder Änderung: Stockwerk 1 (`tools/tests.sh`) und, wo die
  App-Schicht berührt ist, Stockwerk 2 (`tools/apptests.sh`). Beides dauert
  zusammen unter einer Minute. Für Änderungen an der Oberfläche läuft
  gezielt der betroffene UI-Fall (`-only-testing:`).
- **Der komplette Lauf** (`tools/uitests.sh` über das ganze Schema und
  `tools/coverage.sh`) dauert über sechs Minuten und läuft **nur auf
  Anforderung**, nicht automatisch vor einem Commit. Neue oder geänderte
  Tests werden trotzdem mitgeschrieben, damit die 100 % beim nächsten
  angeforderten Lauf halten; ob sie halten, ist erst dann belegt.

### Der eine Grundsatz

**Ein Sollwert, der aus dem Programm stammt, prüft nichts.** Er beschreibt
nur, was das Programm gerade tut — auch wenn es falsch ist. Sollwerte für
Rechnungen sind von Hand nachgerechnet und im Test nachvollziehbar
hergeleitet (Beispiel: 1000 g Mehl, 700 g Wasser → 70 % Hydration; mit
200 g Anstellgut bei 100 % Hydration sind es insgesamt 1100 g Mehl, 800 g
Wasser, also 72,7 %). Niemals einen Testlauf ausführen und dessen Ausgabe
als Erwartung eintragen.

### Drei Stockwerke

| | Stockwerk | Prüft | Werkzeug | Skript |
| --- | --- | --- | --- | --- |
| 1 | **Rechenlogik** | jede Funktion in `SourdoughKit` | Swift Testing, `swift test` | `tools/tests.sh` |
| 2 | **App-Schicht** | Speicherung, View-Modelle, Formatierung | Swift Testing im Simulator | `tools/apptests.sh` |
| 3 | **Oberfläche** | jeder Bildschirm, jede Bedienhandlung | XCUITest | `tools/uitests.sh` |

Anders als in einer Testpyramide üblich ist Stockwerk 3 **nicht** auf eine
Handvoll Fälle beschränkt: Jeder Bildschirm wird von einem UI-Test
erreicht, jedes Bedienelement mindestens einmal betätigt und sein Ergebnis
auf dem Bildschirm geprüft. Dazu gehören Fehlerfälle der Eingabe (leere
Felder, Null, unsinnige Werte) und das Wiederherstellen nach einem
Neustart der App.

Regeln für UI-Tests:

- Elemente werden über `accessibilityIdentifier` gefunden, nicht über
  sichtbare Texte; die Texte dürfen sich ändern, ohne dass Tests brechen.
- Jeder Test startet die App in einem definierten Zustand und hinterlässt
  keinen gespeicherten Stand, der einen späteren Test oder den echten
  Gebrauch beeinflusst.
- Kein `sleep`; gewartet wird mit `waitForExistence(timeout:)` oder
  Erwartungen auf Elementzustände.

### Befehle

```bash
tools/tests.sh
```

Stockwerk 1, ohne Simulator, in Sekunden. Gleichwertig zu
`cd SourdoughKit && swift test --enable-code-coverage`.

```bash
tools/apptests.sh
```

Stockwerk 2, im Simulator ohne Bedienung.

```bash
tools/uitests.sh
```

Das ganze Schema, also auch die App-Fälle; braucht einen Simulator und
dauert gut sechs Minuten (Stand 2026-11-08, 19 UI-Fälle auf einem
MacBook Air mit 16 GB). Die Zeit steckt in XCUITest selbst: rund 6,5 s je
App-Start und 1 bis 3 s je Bedienschritt. Paralleles Testen ist
ausgeschaltet, weil es hier einzelne Fälle bis zu zehnmal langsamer machte;
`PARALLEL=YES WORKERS=<n>` schaltet es ein. Läuft nebenher die Live-Ansicht des Simulators in der
Claude-App, werden die Tests so langsam, dass einzelne Fälle an
Zeitüberschreitungen scheitern können; ein solcher Fall besteht einzeln
(`-only-testing:`) meist, und das ist dann kein Codefehler.

```bash
tools/coverage.sh
```

Führt alle drei Stockwerke mit Abdeckungsmessung aus
(`swift test --enable-code-coverage` und `xcodebuild test
-enableCodeCoverage YES -resultBundlePath …`), wertet sie mit
`llvm-cov report` bzw. `xcrun xccov view --report` aus und endet mit einem
Fehlercode, sobald eine Datei in `SourdoughKit/Sources/` oder `Sourdough/`
unter 100 % Zeilenabdeckung liegt. Ausgenommen sind nur `#Preview`-Blöcke;
jede weitere Ausnahme steht mit Begründung im Skript, nicht im Code
verstreut.

**Bezugsgeräte:** Das echte iPhone ist „Zackebuh“ (iPhone 15 Pro Max,
UDID `00008130-000045A93C30001C`), der Simulator ein **iPhone 15** (ohne
Pro Max, 393 × 852 Punkte) mit iOS 27. Die Oberfläche wird für die
Bildschirmgröße des iPhone 15 gestaltet und mit den UI-Tests dort geprüft;
auf Zackebuh darf sie nichts verlieren, wird aber nicht dafür optimiert.
`tools/simulator.sh` liefert die UDID des Simulators „iPhone 15 (iOS 27)“
und legt ihn an, falls er fehlt: Das vorinstallierte iPhone 15 hat nur
iOS 17 und kann die App nicht laden. Die Skripte nehmen ihn als Voreinstellung;
ein anderer Simulator wird als UDID übergeben. Simulatoren immer über `id=`
ansprechen, nie über `name=`; Gerätenamen sind nicht eindeutig.

## Startparameter für Tests

Jeder UI-Test startet die App in einem definierten Zustand:

- `-skipSplash` überspringt die Startanimation.
- `-resetData` vergisst alle gespeicherten Daten (Utensilien). Ein Neustart
  innerhalb eines Tests lässt ihn weg, um das Speichern zu beweisen.
- `-splashSeconds <n>` dehnt die Startanimation, damit ein Test sie sicher
  sieht.
- `-seedEquipment all|none` speichert beim Start Utensilien (alles in den
  Nicht-Standard-Varianten, beziehungsweise „eingerichtet, aber nichts
  vorhanden“), damit ein Test nicht erst durch den Wizard klicken muss. Nur
  ein Test geht die ganze Strecke durch den Wizard
  (`EquipmentSavedTests.testEverythingSavedIsShownAndSurvivesRestartingTheApp`).

Ohne Parameter startet die App so, wie eine Nutzerin oder ein Nutzer sie
vorfindet. Die Parameter wirken nur über `LaunchOptions` und sind in
`SourdoughTests/LaunchOptionsTests.swift` geprüft.

## Build-Einstellungen

| Einstellung | Wert |
| --- | --- |
| Bundle-Identifier | `de.superook.Sourdough` |
| Unterstützte Plattformen | `iphoneos iphonesimulator` |
| Gerätefamilie | nur iPhone (`TARGETED_DEVICE_FAMILY = 1`) |
| `SDKROOT` | `auto` |
| Deployment-Target | iOS 27.0 |
| Swift-Sprachmodus | 6 (strikte Nebenläufigkeitsprüfung) |

Kein iPad und kein macOS: Beides wäre ein weiteres Layout, das gepflegt und
mit UI-Tests abgedeckt werden müsste. `SourdoughKit` gilt mit
`swift-tools-version` 6 ebenfalls im Swift-6-Modus.

## Konventionen

- Ausschließlich SwiftUI. Kein UIKit, sofern nicht eine bestimmte API dazu
  zwingt.
- Views enthalten `#Preview`-Blöcke. Previews funktionsfähig halten; sie
  sind die schnellste Rückmeldung in diesem Projekt.
- Das Deployment-Target ist aktuell gewählt, neuere Plattform-APIs dürfen
  also ohne Verfügbarkeitsprüfung verwendet werden.
- **Sprachen:** Bezeichner, Kommentare und Commit-Nachrichten auf Englisch.
  Dokumentation und **sichtbare Texte in der Oberfläche** auf Deutsch. Die
  Trennung hält die deutschen Zeichenketten beisammen, falls die App später
  internationalisiert wird.
- **Anrede in der Oberfläche:** Die Nutzerin oder der Nutzer wird mit „du“
  angesprochen, ohne Annahme über das Geschlecht. Formulierungen richten
  sich an die Handlung oder die Sache („Dein Teig“, „Gib die Mehlmenge
  ein“), nicht an eine Personenbezeichnung für die Person am Gerät.
- **Berufs- und Personenbezeichnungen** in sichtbaren Texten stehen in
  weiblicher und männlicher Form: „Bäckerinnen und Bäcker“.

## Hinweise zum Repository

- **Worktrees für parallele Sitzungen** legt das Werkzeug `EnterWorktree`
  an, nicht `git worktree add` von Hand: Es setzt sie nach
  `.claude/worktrees/<name>` auf einen neuen Branch; der Ordner ist
  ignoriert. **Vorsicht beim Ausgangspunkt:** Die Voreinstellung
  (`worktree.baseRef: fresh`) zweigt von `origin/<Standardbranch>` ab, also
  von `main` und nicht vom aktuellen Stand. Liegt Arbeit noch nicht in
  `main`, fehlt sie dort; dann `worktree.baseRef: head` einstellen oder
  einen von Hand angelegten Worktree betreten (`EnterWorktree` mit `path`;
  er muss unter `.claude/worktrees/` liegen). In einem Worktree nur die
  eigenen Pfade stagen, nie `git add -A`.
- Das Remote `origin` ist `github.com/SuperOok/sourdough` und wird als
  **öffentlich** behandelt. Niemals API-Schlüssel, Provisioning-Profile
  oder Signaturzertifikate einchecken. Ebenso keine wörtlich übernommenen
  Rezepttexte oder Bilder aus Büchern und Websites — Mengenverhältnisse
  als solche sind frei, ihre konkrete Ausformulierung und Gestaltung nicht.
- `xcuserdata/` ist ignoriert. Das Schema „Sourdough“ liegt dagegen als
  **geteiltes** Schema unter `Sourdough.xcodeproj/xcshareddata/` und ist
  eingecheckt — sonst wüsste `xcodebuild test` in einem frischen Klon
  nicht, welche Testtargets gemeint sind.
- `CLAUDE.md` ist ein Symlink auf diese Datei. Geändert wird nur
  `AGENTS.md`.
