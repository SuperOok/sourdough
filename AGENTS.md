# Sourdough

SwiftUI-App fürs iPhone, gebaut mit Xcode 27.

Sourdough ist eine **Hilfe-App für Brot mit Sauerteig**. Geplant ist ein
Rezeptrechner (Bäckerprozente, Hydration, Anteil des Anstellguts, Skalieren
auf eine Teigmenge); gebacken wird in der eigenen Küche. Zeitpläne,
Starter-Pflege und Backtagebuch gehören nicht zum Umfang.

**Der Teigrechner ist vorerst abgeschaltet** (2026-11-08): Er soll später
anders aussehen und kostete viel Testzeit. Die Rechenlogik `Dough` bleibt im
Package, getestet und ohne Oberfläche; Ansicht und Eingabe-Modell
(`CalculatorView`, `DoughViewModel`) sind aus der App entfernt und stehen in
der Git-Historie (Commit „Add project scaffold“).

Der Code ist zweierlei. `Sourdough/` ist die App: Oberfläche und
Speicherung. `SourdoughKit/` ist ein Swift Package mit der **Rechenlogik**,
ohne Xcode-Projekt und ohne Simulator prüfbar.

Stand 2026-11-09: Startanimation (Platzhalter), Startbildschirm mit
Platzhalter-Foto und drei Optionen (Backutensilien, Sauerteigstarter, Tipps
und Tricks), Utensilien-Liste mit Speicherung, Tipps und Tricks,
Starter-Protokoll. Weitere Startoptionen
sind noch zu planen. Der letzte volle Lauf mit Abdeckung 100 % ist vom
2026-11-09 (siehe „Wann welcher Lauf“).

## Aufbau

```
Sourdough.xcodeproj    drei Targets, „Sourdough“, „SourdoughTests“ und
                       „SourdoughUITests“, dazu ein geteiltes Schema
                       „Sourdough“
SourdoughKit/          Swift Package: die Rechenlogik samt Tests
  Sources/SourdoughKit   `Dough` (Hydration mit Anstellgut), `EquipmentItem`
                         (Backutensilien, mit `Dimensions` und Volumen), `Starter` mit `Feeding` und die
                         Zustandsberechnung (`StarterModel`), Tipps
                         (`TipsTopic`, `TipsCatalog`, `TipsParser`) —
                         Werttypen und reine Funktionen
    Tips/*.md            die Texte der Tipps-Seiten, eine Datei je Thema
  Tests/SourdoughKitTests
Sourdough/             Quellcode der App
  SourdoughApp.swift   @main, WindowGroup
  ContentView.swift    Wurzel: Splash über dem Startbildschirm
  SplashView.swift     Startanimation (Platzhalter)
  StartView.swift      Startbildschirm: Foto-Platzhalter und Optionen
  TipsView.swift       Tipps und Tricks: Inhaltsverzeichnis, Seite, Button
  TipsText.swift       Inline-Markdown und `tip:`-Links
  EquipmentOverviewView.swift   Liste der Utensilien, „+“-Menü, fehlende Arten
  EquipmentFormView.swift, EquipmentForm.swift   Formular (neu/ändern) und Modell
  EquipmentStore.swift Speicherung (UserDefaults, JSON, Schlüssel `equipment.v2`)
  EquipmentText.swift  deutsche Beschreibung der Utensilien
  EquipmentDemo.swift  Demo-Utensilien für UI-Tests
  StarterListView.swift, StarterDetailView.swift, StarterEditViews.swift
                       Starter: Liste, Detail, Anlegen, Füttern
  StarterStore.swift   Speicherung der Starter (UserDefaults, `starters.v1`)
  StarterForms.swift   Formular-Modelle (Anlegen, Füttern), Zahleneingabe
  StarterText.swift    deutsche Texte: Zustände, Dauer, Datum, Zusammenfassung
  StarterDemo.swift    Demo-Starter für UI-Tests
  LaunchOptions.swift  Startparameter für Tests
  LaunchSetup.swift    wendet sie einmal beim App-Start an
  Refreshing.swift     setzt „jetzt“ jede Minute neu
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
dauert eine Viertelstunde (Stand 2026-11-09, 38 UI-Fälle auf einem
MacBook Air mit 16 GB, nebenher lief ein Build). Die Zeit steckt in XCUITest selbst: rund 6,5 s je
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

## Backutensilien

Die Utensilien sind eine **Liste einzelner Stücke** (`EquipmentItem`): Von
einer Art (`EquipmentKind`: Küchenmaschine, Bräter/Römertopf, Kastenform,
Gärkörbchen) kann es mehrere geben, jedes mit eigenem Namen. Über das „+“
der Symbolleiste (ein Menü mit den vier Arten) öffnet das Formular für ein
neues Stück; ein Tipp auf eine Zeile öffnet dasselbe Formular zum Ändern,
dort steht auch „Utensil löschen“ (mit Rückfrage). Der **Name ist
optional**: Ohne Eingabe heißt das Stück wie seine Art, der Platzhalter im
Feld zeigt das.

Welche Angaben ein Stück hat, hängt von der Art ab (`EquipmentKind`):
Bräter und Kastenform haben eine Silikoneinlage (ja/nein), die Kastenform
dazu Material (Blech/Gusseisen) und Deckel. Bräter und Kastenform haben
außerdem **optionale Innenmaße** in Zentimetern (`Dimensions`): Form
rechteckig (Länge × Breite × Höhe), oval (π/4 × Länge × Breite × Höhe) oder
rund (π/4 × Durchmesser² × Höhe), daraus das Volumen in Litern, auf eine
Nachkommastelle gerundet. Alle Felder leer (oder 0) heißt „keine Maße“;
sind nur einige gefüllt, ist das Formular ungültig („Gib alle Maße an oder
keines.“). Ein neuer Bräter beginnt rund, eine neue Kastenform rechteckig.
Angaben, die nicht zur Art passen, werden beim Speichern auf die
Voreinstellung zurückgesetzt.

Unter der Liste steht „Nicht vorhanden, aber sinnvoll“: die Arten, von denen
es noch kein Stück gibt. Sie erscheint erst, wenn die Liste nicht leer ist,
und nur, wenn eine Art fehlt. Hinter jedem Eintrag und im Formular steht ein
Glühbirnen-Symbol (`TipsIconButton`, im Formular `TipsButton` mit
`identifier` `item-tips`), das die Tipps-Seite der Art als Sheet öffnet.

Bezeichner: `equipment-add` (das „+“-Menü) und `equipment-add-<art>`,
`equipment-row-<name>` (Zeile), `equipment-tip-<name>`, `missing-<art>` und
`missing-tip-<art>`, `equipment-empty`; im Formular `item-name`,
`item-material`, `item-lid`, `item-liner`, `item-shape`, `item-length`,
`item-width`, `item-height`, `item-volume`, `item-error`, `item-save`,
`item-cancel`, `item-delete`, `item-tips`. `<art>` ist der Rohwert von
`EquipmentKind` (`kneader`, `pot`, `pan`, `basket`).

Gespeichert wird unter `equipment.v2`. Der frühere Eintrag `equipment.v1`
(feste Felder statt Liste, aus der Zeit des Wizards) wird nicht übernommen.

## Sauerteigstarter

Ein Starter hat Name, Mehlsorte (Roggen, Weizen, Dinkel), Ansetzdatum, einen
Aufbewahrungsort (Raumtemperatur oder Kühlschrank mit Temperatur von 0 bis
15 °C) und ein Protokoll von Fütterungen (behaltener Starter, Mehl, Wasser,
Zeitpunkt). Das Anlegen ist die erste Fütterung, ohne behaltenen Starter.

**Der Zustand ist eine Schätzung** (`StarterModel`, Beschreibung im
Dokumentationskommentar und in der Tipps-Seite „So wird der Zustand
berechnet“): Aus der Verdünnung bei der letzten Fütterung (Starter + Mehl +
Wasser im Verhältnis zum behaltenen Starter) folgt die Zahl der
Verdopplungen; eine Verdopplung dauert bei 22 °C 3 Stunden für Weizen
(Roggen ×0,8, Dinkel ×0,9) und je 10 °C kälter dreimal so lang. Daraus
ergeben sich die Zeit bis zum Höhepunkt und die Grenzen: bester Bereich bei
0,75 bis 1,5, hungrig bei 2,5, lange nicht gefüttert bei 4 Höhepunkt-Zeiten.
Der Zeitpunkt „füttern oder verwenden bis“ ist die Hungrig-Grenze. Alle
Konstanten stehen an einer Stelle in `StarterModel`. Sie sind Richtwerte und
nicht an echten Startern gemessen; wer sie ändert, ändert die Sollwerte in
`StarterTests` von Hand nach.

Ohne Kühlschrank gilt der Starter als bei 22 °C aufbewahrt (`Starter.roomCelsius`).

## Tipps und Tricks

Die Texte sind **Markdown-Dateien** unter
`SourdoughKit/Sources/SourdoughKit/Tips/`, eine je Thema, im Package
mitgeliefert. Erlaubt ist eine kleine Teilmenge: `# Titel` (genau einmal, am
Anfang), `## Abschnitt`, `- Listenpunkt`, Absätze und Inline-Markdown
(**fett**, *kursiv*, Links). Quer-Verweise sind Links der Form
`[Kastenform](tip:pan)`.

**Ein neues Thema** braucht drei Schritte: einen Fall in
`TipsTopic.ID` (der Rohwert ist der Dateiname), die Datei `Tips/<id>.md` und
eine Zeile in `TipsTopic.category`. Das Inhaltsverzeichnis in der App
entsteht daraus von selbst. `TipsCatalogTests` prüft, dass jedes Thema eine
Datei mit Titel und Inhalt hat und jeder `tip:`-Link ein Thema trifft. Die
Utensil-Themen tragen dieselben Ids wie die Arten der Utensilien
(`kneader`, `pot`, `pan`, `basket`); das prüft `TipsTextTests`.

**Aufruf aus jeder Ansicht:** Die Tipps öffnen als Sheet über der aktuellen
Ansicht (`TipsButton` in der Symbolleiste, im Utensilien-Formular direkt mit der
Seite der Art). „Fertig“ schließt das Sheet, darunter bleibt alles
unverändert. Neue Ansichten bekommen einen `TipsButton`; sitzt er in einer
Ansicht, über der schon ein Sheet mit eigenem Knopf liegt, braucht er eine
eigene `identifier`.

**Links in Text:** Die `openURL`-Aktion hängt an der Seite selbst, nicht am
`NavigationStack`; dort kam sie nicht an. Das URL aus dem Markdown hat kein
`path`, `TipsText.topicID(from:)` liest deshalb den ganzen String.

## Startparameter für Tests

Jeder UI-Test startet die App in einem definierten Zustand:

- `-skipSplash` überspringt die Startanimation.
- `-resetData` vergisst alle gespeicherten Daten (Utensilien, Starter). Ein Neustart
  innerhalb eines Tests lässt ihn weg, um das Speichern zu beweisen.
- `-splashSeconds <n>` dehnt die Startanimation, damit ein Test sie sicher
  sieht.
- `-seedStarters demo` speichert zwei Starter in bekannten Zuständen
  (Roggen im Kühlschrank, vor einer Stunde gefüttert: „Reift“; Weizen bei
  Raumtemperatur, vor drei Tagen gefüttert: „Lange nicht gefüttert“).
- `-seedEquipment all` speichert fünf Utensilien (`EquipmentDemo`):
  Küchenmaschine „Thermomix“, ovaler Römertopf mit Einlage (30 × 20 × 12 cm,
  5,7 l), „Gusseisenform“ mit Deckel und Einlage (30 × 10 × 8 cm, 2,4 l),
  eine schlichte „Kastenform“ ohne Maße und ein „Gärkörbchen“, damit ein
  Test nicht erst alles anlegen muss. Nur ein Test legt ein Stück über das
  Formular an und startet danach neu
  (`EquipmentListTests.testAddingAPanShowsItWithItsVolumeAndSurvivesRestartingTheApp`).

Ohne Parameter startet die App so, wie eine Nutzerin oder ein Nutzer sie
vorfindet. Zurücksetzen und Vorbelegen geschieht einmal im App-Start
(`LaunchSetup`), nicht im `init` einer View: Das läuft bei jedem Neuaufbau
der View erneut und würde die Demo-Starter mit neuen Ids neu anlegen. Die Parameter wirken nur über `LaunchOptions` und sind in
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
