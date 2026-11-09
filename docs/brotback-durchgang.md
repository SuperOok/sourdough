# Brotback-Durchgang: Plan

Stand 2026-11-09. Planungsdokument für die neue Startoption „Brot backen“.
Fachliche Grundlage ist `docs/sauerteig-diskussion.md`; Zahlen daraus sind
Richtwerte, nicht gemessen.

## Entscheidungen

| Frage | Entscheidung |
| --- | --- |
| Brotarten zum Start | die sechs Brote der Tabelle in der Diskussion: Dinkelbrot, Dinkel-Mischbrot, Roggenmischbrot 50, Roggenmischbrot 70, Roggenbrot 80, Roggenvollkorn |
| Mehle | Weizen 405, 550, 1050, Vollkorn · Roggen 997, 1150, 1370, Vollkorn · Dinkel 630, 1050, Vollkorn |
| Mehlvorrat | keiner. Im Plan lassen sich feste Obergrenzen je Mehl in Gramm eingeben („höchstens 235 g Dinkel 1050“). |
| Temperaturen | Raum- und Kühlschranktemperatur sind im Durchgang einstellbar; die App merkt sich die Werte für den nächsten Durchgang. Annahme: Beim Starter wird die Raumtemperatur ebenso einstellbar wie heute schon die Kühlschranktemperatur (bisher fest 22 °C). |
| Zeitleiste | Variante B: Übersichtsleiste plus Liste. Kein Gantt. Schwäche: Die Tage sind in der Leiste schlecht zu erkennen. Verbesserung für später: Mitternacht als Trennlinie, Tageskürzel über der Leiste. |
| Ablaufdefinition | typgeprüfte Swift-Werte im Package, Texte als Markdown mit Platzhaltern |
| Starter-Raumtemperatur | je Starter einstellbar wie die Kühlschranktemperatur, vorbelegt mit dem zuletzt benutzten Wert |
| Backwege | Kastenform · Gärkörbchen + Bräter · Gärkörbchen + Blech · ohne Gärkörbchen: Gare in einer Schüssel, dann Bräter oder Blech. Schüssel und Blech gelten als immer vorhanden. |
| Mitteilungen | nicht in Stufe D, später |
| Gleichzeitige Durchgänge | nur einer; ein neuer beginnt erst nach Abschluss oder Abbruch |
| Hefe | nur als Hinweis in den Tipps, nicht im Rezept |
| Arbeitsweise | offene Arbeit vorab committen, dann ein lokaler Commit je Stufe auf `main`, kein Push; vor jedem Stufen-Commit der volle Lauf (`tools/coverage.sh`); keine Installation auf dem iPhone |

## Ablauf eines Durchgangs

1. **Planen**
   - Brotart wählen.
   - Starter wählen.
   - Mehlmischung anpassen.
   - Utensilien wählen.
   - Zeitplan festlegen.
2. **Durchführen:** Die Anleitung Schritt für Schritt abhaken. Der Stand übersteht einen Neustart der App.
3. **Protokoll:** Eine Kopie aller Parameter mit Soll- und Ist-Zeiten.

## Fachmodell

### Mehle

- Ein Mehl ist Getreide (Weizen, Roggen, Dinkel) plus Typ oder Vollkorn.
- Jedes Mehl hat eine Bezugs-Wasseraufnahme. Alle Konstanten stehen an einer Stelle.
- Die Hydration der Mischung ist der gewichtete Mittelwert. Vollkorn liegt etwa 5–10 Prozentpunkte über dem hellen Mehl desselben Getreides.
- In den Presets steht „hell“ für Roggen 1150 und Dinkel 1050. Das sind die Mehle der Beispielrechnungen in der Diskussion.

**Ersatzregeln** in der Reihenfolge, in der die Anpassung sie versucht:

1. Gleiches Getreide, benachbarter Typ: 1:1, etwa 2–3 Prozentpunkte Wasser je Stufe Richtung Vollkorn.
2. Weizen und Dinkel gleichen Typs: 1:1. Dinkel braucht etwas weniger Wasser und kürzer kneten.
3. Sonst proportional auf die übrigen Mehle verteilen.

Roggen ist nicht frei gegen Weizen oder Dinkel tauschbar. Das verhindern die Grenzen.

### Grenzen

- **Roggenanteil der Brotart:** Für jede Brotart gilt ein erlaubter Bereich um das Preset. Beim Verschieben bleibt der Roggenanteil darin.
- **Ab etwa 30 % Roggen** ist Roggensauerteig nötig. Starter mit anderem Mehl werden dann als ungeeignet markiert. 30–40 % des Roggens werden versäuert.
- **Freigeschoben** (Gärkörbchen, Bräter): höchstens etwa 50 % Roggen. Ab etwa 70 % nur Kastenform.
- **Obergrenze in Gramm je Mehl:** Ein überschrittener Anteil wird nach den Ersatzregeln umverteilt. Geht das nicht, ohne eine Grenze zu verletzen, ist der Plan ungültig und benennt die verletzte Grenze.
- **Anzeige:** Jeder Anteil zeigt den Bereich, in dem er sich verschieben lässt, ohne eine Grenze zu verletzen.

### Mengen

- **Kastenform:** Volumen × etwa 60 % Füllung × etwa 0,5 g/ml ergibt die Teigmenge.
- **Bräter:** Teigmenge aus dem Durchmesser; 27 cm entsprechen etwa 1 kg.
- **Daraus folgen** Mehl, Wasser, Salz und Vorteig in Gramm. Die vorhandene Rechenlogik `Dough` (Hydration mit Anstellgut) wird dafür wieder benutzt.

### Zeitplan

- **Phasen:** Jede Phase ist eine Handlung oder eine Ruhe.
  - Eine Ruhe hat eine Nenndauer sowie eine kürzeste und eine längste sinnvolle Dauer.
  - Hebel für eine Ruhe: warm (26–28 °C), Raumtemperatur, Kühlschrank, warmes Wasser.
  - Für das Schüttwasser gilt: Wassertemperatur = 2 × Teig-Zieltemperatur − Mehltemperatur.
- **Dauer abhängig von der Temperatur:** Je 10 °C kälter dauert eine Phase dreimal so lang. Das ist dieselbe Regel wie beim Starter.
- **Rückwärtsplanung:** Geplant wird von der Zielzeit (anschnittfertig) zurück. Die Zielzeit wird mit dem grafischen DatePicker gewählt.
- **Zeitfenster:** Handlungen liegen zwischen 8 und 21 Uhr.
  - Fällt eine Handlung heraus, wird eine benachbarte Ruhe gedehnt oder gestaucht oder ein Hebel gewechselt.
  - Gelingt das nicht, wird ein Konflikt angezeigt.
- **Darstellung:** Variante B, Übersichtsleiste mit Swift Charts (`RectangleMark`) und darunter die Liste.

### Ablauf und Entscheidungen

- **Definition:** Die Schritte sind Swift-Werte im Package. Die Texte sind Markdown mit Platzhaltern (`{starter.name}`, `{form.name}`, Mehlmengen).
- **Entscheidungen:** Sie sind Schritte mit Antwortknöpfen, zum Beispiel „reif“ oder „noch nicht“. Eine Antwort ändert die folgenden Schritte und deren Zeiten.
- **Diagramm:** Ein Mermaid-Diagramm wird aus derselben Definition erzeugt.
- **Noch nicht im Entwurf:**
  - Quellstück bei Vollkorn
  - Hefe als Sicherheit
  - „übergar, sofort backen“
  - Kerntemperatur als Garprobe

### Protokoll

- Jeder Durchgang ist eine JSON-Datei im App-Ordner, nicht in `UserDefaults`, weil später Fotos dazukommen.
- Starter und Utensil werden als Kopie gespeichert, damit spätere Änderungen das Protokoll nicht verfälschen.

## Stufen

Jede Stufe ist ein eigener Commit mit vollständigen Tests. Die Stufen A bis C
hängen im Bildschirmfluss eng zusammen (Schritt 2 setzt die Mehlmenge von
Schritt 1, Schritt 3 braucht beide) und sind deshalb ein gemeinsamer Commit.
Die Umsetzung weicht in Einzelheiten von diesem Plan ab; maßgeblich ist der
Abschnitt „Brot backen“ in `AGENTS.md`.

| Stufe | Inhalt | Ergebnis |
| --- | --- | --- |
| A | Mehlmodell, Brotarten, Grenzen, Anpassen, Obergrenzen, Wasser | Planbildschirm Schritt 1 |
| B | Utensilwahl, Teigmenge aus der Form, Rezept in Gramm | Schritt 2 mit Mengen |
| C | Phasenmodell, Temperaturen (gemerkt), Rückwärtsplanung, Zeitfenster, Hebel | Zeitleiste |
| D | Ablaufdefinition, Platzhalter-Texte, Entscheidungen, Mermaid-Export | Anleitung abhaken, übersteht einen Neustart |
| E | Protokoll als Kopie, Liste der Durchgänge | Verlauf |

### Stufe A im Einzelnen

**Package (`SourdoughKit`):**

- `Grain` und `Flour`:
  - die elf Mehle der Liste
  - Bezugs-Wasseraufnahme je Mehl
  - deutsche Namen in der App-Schicht
- `BreadType`:
  - die sechs Brote
  - Preset-Anteile
  - Hydrationsbereich
  - erlaubter Roggenbereich
  - freigeschoben erlaubt ja/nein
  - Roggensauerteig nötig ja/nein
- `FlourMix`:
  - Anteile mit Summe 100 %
  - Roggen- und Vollkornanteil
  - Hydration
  - Mehl ersetzen
  - Anteil ändern mit Umverteilung nach den Ersatzregeln
  - zulässiger Bereich je Anteil
- **Prüfung** gegen Brotart, Starter und Obergrenzen, mit benannten Verstößen.
- **Gesamtmehl:** In Stufe A wird es von Hand eingegeben; Stufe B leitet es aus der Form ab. Obergrenzen in Gramm brauchen eine Gesamtmenge.

**App:**

- **Startoption „Brot backen“.**
- **Planbildschirm Schritt 1:**
  - Brotart wählen.
  - Starter wählen; ungeeignete werden markiert und begründet.
  - Mehltabelle mit Anteil, Gramm und zulässigem Bereich.
  - Mehl tauschen.
  - Obergrenze eingeben.
  - Hydration und Wasser in Gramm.
- **Tipps:** Eine neue Tipps-Seite erklärt die Mehltypen und die Ersatzregeln.

**Sollwerte von Hand**, zum Beispiel:

- Roggenmischbrot 50 mit 825 g Mehl: 25/25/30/20 % ergeben 206,25 / 206,25 / 247,5 / 165 g.
- Ein Roggenanteil von 412,5 g entspricht 50 %.
