# Version 1.2 – Umsetzungsplan (2026-11-14)

Ziel: neue Version für die Testerin am späten Nachmittag. Umsetzung in einem
Rutsch ohne Rückfragen; alle Entscheidungen werden vorab geklärt und unten
eingetragen.

## Zeitrahmen

- Start nach Klärung der Fragen (etwa 12 Uhr).
- Keine harte Stichzeit mehr (Nachricht des Entwicklers): nach hinten offen,
  nichts wegen der Zeit abbrechen; alle Verbesserungen vollständig umsetzen.
- Lange UI-Testläufe bündeln: je Arbeit die nötigen UI-Klassen in einem
  `xcodebuild`-Aufruf mit mehreren `-only-testing:`, nur Fehlschläge einzeln
  wiederholen; am Ende ein einziger voller Lauf mit Abdeckung.
- 15:30–17:00: voller UI-Lauf mit Abdeckung (`tools/coverage.sh`, über 1 h),
  Korrekturen, Version 1.2 (Build 1), Release-Build, Installation.

## Reihenfolge und Parallelität

Jede Verbesserung auf eigenem Branch in eigenem Worktree, eigener Simulator
(`w1-*`, `w2-*`), nie zwei `xcodebuild` auf demselben Simulator. Zusammengeführt
wird in `release/1.2` (von `feature/icons-buckwheat-proofing`).

| Welle | Arbeit | hängt ab von | parallel zu |
| --- | --- | --- | --- |
| 1 | **VB-006** Ablaufmodell, PlantUML | – | VB-007, VB-001/002, VB-003 |
| 1 | **VB-007** Starter erhalten (Artikel, Texte) | – | alles |
| 1 | **VB-001 + VB-002** drei Wege beim Anlegen, Ansetzphase | – (Ansetzphase berührt den Ablauf nicht) | VB-006 |
| 1 | **VB-003** Kühlschrank (Recherche, dann Umsetzung) | Entscheidung unten | VB-006 |
| 2 | **VB-004 + VB-005** Falt-Runden, Knetwerkzeug | VB-006 | – |
| 3 | Zusammenführen, voller Lauf, Release | alles | – |

Prüfung je Verbesserung: Stockwerk 1 und 2 vollständig, Stockwerk 3 gezielt
(`-only-testing:`); der volle Lauf nur einmal am Ende.

Konflikte beim Zusammenführen: `AGENTS.md`, `TipsTopic.swift`,
`StarterModel.swift` (VB-002/003), `BakeProcess.swift` (VB-006/004/005/007).
Reihenfolge der Merges: 007, 006, 001/002, 003, 004/005.

## Abbruchregeln (ohne Rückfrage)

- Ein Test, der nur unter Last scheitert und einzeln besteht: kein Fehler,
  vermerken.
- Abdeckung unter 100 % in einer neuen Datei: Tests ergänzen; geht das bis
  16:30 nicht, die Verbesserung herausnehmen statt die Ausnahme ins Skript zu
  schreiben.
- Fachliche Zahlen, die die Recherche nicht trägt: als Richtwert eintragen und
  in der VB-Datei als „nicht belegt“ markieren, nicht raten.
- Neue Icons: keins erfinden; vorhandenes nehmen, Vorschlag in der VB-Datei.
- Nichts nach `main`, keine Force-Pushes.

## PlantUML

- Lizenz: MIT-Ausgabe der Jar (nur Entwicklungswerkzeug, nicht in der App;
  erzeugte Diagramme unterliegen nicht der Lizenz der Jar).
- Jar außerhalb des Repos (Binärdatei, eigene Lizenz):
  `/Library/Application Support/PlantUML/plantuml-mit-1.2026.10.jar`, gesetzt in
  der Umgebungsvariablen `PLANTUML_JAR`; die Skripte lesen nur diese Variable und
  brechen mit einer Meldung ab, wenn sie fehlt.
- Java 22 (Temurin) ist installiert; Graphviz nicht. Geprüft 11:59: Ein
  Aktivitätsdiagramm (neue Syntax, mit `if` und `repeat`) wird ohne Graphviz als
  SVG erzeugt.
- `tools/diagrams.sh` erzeugt aus den `.puml`-Dateien unter `docs/` SVGs, die
  eingecheckt werden (GitHub zeigt PlantUML nicht direkt an).

## Entscheidungen (vorab geklärt)

- **Auslieferung:** Release-Build fertig bauen; die Installation auf das
  iPhone der Testerin macht der Entwickler selbst. Keine Installation auf
  Zackebuh in diesem Lauf.
- **Git ohne Rückfrage:** Commits auf Branches, Push von `release/1.2` (und der
  Verbesserungs-Branches), `verbesserungen/` einchecken. Nie `main`.
- **Vorrang bei Zeitnot:** VB-006 zuerst, dann so viel vom Rest, wie bis
  15:30 fertig wird.
- **Diagramme:** Nur PlantUML. Mermaid in `docs/ablauf.md` fällt weg; die
  Ansichten werden mit der PlantUML-Jar erzeugt (SVG, eingecheckt).
- **VB-002:** alle Vorgaben bestätigt – drei Antworten (verdoppelt / etwas /
  nicht), bereit nach zwei „verdoppelt“ in Folge, Füttern alle 24 h, Starter in
  der Ansetzphase sperrt „Durchgang starten“, Phasengrenzen 2/3/5/10/14 Tage bei
  22 °C nach Gegenprüfung.
- **VB-003:** Option **B + C** (eigene Kühlschrank-Zustände und Begründung im
  Detail), sofern die Recherche die heutigen Grenzen als zu streng bestätigt;
  sonst nur C.
- **VB-004/005:** Regelvorschlag und Details bestätigt – Runden nach Hydration
  2/3/4, Dinkel höchstens 3, Roggen 20–50 % und Knetmaschine je eine weniger
  (mindestens 1), letzte Stunde frei, bei kühler Stockgare Falt-Phase bei
  Raumtemperatur vorweg, jede Runde einzeln abhaken, Küchenmaschine
  „Knethaken / Messer“.
- **Optional, beides mit hinein:** VB-007 B („Fütterung eintragen“ im Schritt
  „Sauerteigstufe ansetzen“) und VB-005 Schüsselvolumen (Hinweis bei zu viel
  Teig, etwa 0,4 kg je Liter, optionale Herstellerangabe).

## Stand

- 14:1x: VB-007 in `release/1.2` (41f8e1e). Offen aus dem Bericht:
  `BakeRunScreenTests.testDecisionsWaitOrGoOnAndStepsNameTheAmounts` scheiterte
  zweimal („run-answer-yes fehlt“) und bestand beim dritten Einzellauf; im vollen
  Lauf beobachten.
- 14:15: VB-006 in `release/1.2` (Merge 6b420cf). Der Layout-Test
  `testTheLightbulbSitsBeforeTheRoomBoxAndTheBoxesLineUp` scheiterte seit der
  grauen Eingabekapsel (9d69ef7): Das Feld mit Glühbirne ist ein eigenes Element,
  der Text in der Kapsel, je 12 pt eingerückt. Test angepasst (e46fe00), besteht.
- 14:10–14:20: Nutzungslimit; VB-005 (Commit 5db44b3) und VB-001/002
  (unkommittiert im Worktree) hielten an und sind fortgesetzt; VB-005 führt
  danach `release/1.2` zusammen und setzt VB-004 um.
- 15:0x: VB-001, VB-002 und VB-003 in `release/1.2` (Merge b55fad1). Konflikte
  mit VB-007 aufgelöst: Kategorie „Sauerteigstarter“ jetzt `starter`,
  `starterFromScratch`, `starterCare` (32 Themen); Package 282 Tests, App 263
  Tests grün. Offen bis zum vollen Lauf: UI-Klassen außerhalb der Starter-Tests
  nach dem Merge.
